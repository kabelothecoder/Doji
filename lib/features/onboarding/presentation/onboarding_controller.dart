import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/config_panel.dart';
import '../data/device_services.dart';
import '../data/mock_strategy_parser.dart';
import '../data/onboarding_repository.dart';
import '../domain/config_lines.dart';
import '../domain/onboarding_catalog.dart';
import '../domain/onboarding_step.dart';
import '../domain/profile_doji.dart';
import '../domain/profile_mapper.dart';
import '../domain/strategy_parser.dart';

@immutable
class OnboardingState {
  const OnboardingState({
    required this.steps,
    required this.currentId,
    required this.answers,
    this.skipped = const {},
    this.returnToId,
    this.lastAnsweredId,
    this.error,
    this.parsing = false,
  });

  final List<OnboardingStep> steps;
  final String currentId;
  final Answers answers;
  final Set<String> skipped;

  /// Non-null while editing a line from profile.doji: where to return.
  final String? returnToId;
  final String? lastAnsweredId;

  /// Doji's validation line for the current step.
  final String? error;

  /// AI parsing of the strategy is in flight.
  final bool parsing;

  List<OnboardingStep> get visibleSteps => [
    for (final s in steps)
      if (s.isVisible(answers)) s,
  ];

  OnboardingStep get current => steps.firstWhere((s) => s.id == currentId);
  int get index => visibleSteps.indexWhere((s) => s.id == currentId);
  bool get isEditing => returnToId != null;
  bool get isFirst => index <= 0;

  List<ConfigLineData> get configLines =>
      buildConfigLines(answers, skipped: skipped, highlightStepId: lastAnsweredId);
  int get totalLines => totalConfigLines(answers);

  /// Lines written / lines expected — the handoff's "[██░░] 20% configured".
  double get progress {
    final total = totalLines;
    return total == 0 ? 0 : (configLines.length / total).clamp(0, 1);
  }

  ProfileDoji get profile => profileFromAnswers(answers);

  /// Doji's reply to the previous visible step's answer, or an edit notice.
  String? get reply {
    if (isEditing) return "editing. i'll bring you back after."; // doji voice
    final visible = visibleSteps;
    for (var i = index - 1; i >= 0; i--) {
      final prev = visible[i];
      if (prev.reply == null) {
        if (prev.countsAsAnswer) return null;
        continue; // info steps (manifesto) don't break the chain
      }
      if (skipped.contains(prev.id) || !answers.containsKey(prev.id)) return null;
      return prev.reply!(answers[prev.id], answers);
    }
    return null;
  }

  OnboardingState copyWith({
    String? currentId,
    Answers? answers,
    Set<String>? skipped,
    String? Function()? returnToId,
    String? Function()? lastAnsweredId,
    String? Function()? error,
    bool? parsing,
  }) => OnboardingState(
    steps: steps,
    currentId: currentId ?? this.currentId,
    answers: answers ?? this.answers,
    skipped: skipped ?? this.skipped,
    returnToId: returnToId != null ? returnToId() : this.returnToId,
    lastAnsweredId: lastAnsweredId != null ? lastAnsweredId() : this.lastAnsweredId,
    error: error != null ? error() : this.error,
    parsing: parsing ?? this.parsing,
  );
}

/// The onboarding engine. Steps come from the catalogue; this class only
/// knows how to move between them, keep answers, and persist after every
/// change so onboarding resumes after the app is killed.
class OnboardingController extends Notifier<OnboardingState> {
  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  OnboardingState build() {
    final steps = ref.watch(onboardingStepsProvider);
    final snap = ref.read(onboardingRepositoryProvider).loadSnapshot();
    final valid = snap != null && steps.any((s) => s.id == snap.currentStepId);
    final initial = valid
        ? OnboardingState(
            steps: steps,
            currentId: snap.currentStepId,
            answers: Map.unmodifiable(snap.answers),
            skipped: snap.skipped,
            returnToId: snap.returnToStepId,
            lastAnsweredId: snap.lastAnsweredStepId,
          )
        : OnboardingState(steps: steps, currentId: steps.first.id, answers: const {});
    if (!initial.answers.containsKey(StepIds.timeZone)) {
      unawaited(Future.microtask(_detectTimeZone));
    }
    return initial;
  }

  Future<void> _detectTimeZone() async {
    final tz = await ref.read(timeZoneServiceProvider).detect();
    if (!ref.mounted || state.answers.containsKey(StepIds.timeZone)) return;
    state = state.copyWith(answers: _with(StepIds.timeZone, tz.toJson()));
    await _persist();
  }

  // --- navigation ----------------------------------------------------------

  /// Validates and stores [answer] for the current step, then moves on.
  /// Returns false (and sets [OnboardingState.error]) when invalid.
  Future<bool> submit([Object? answer]) async {
    final step = state.current;
    final error = step.validate?.call(answer);
    if (error != null) {
      state = state.copyWith(error: () => error);
      return false;
    }
    if (step.countsAsAnswer) {
      state = state.copyWith(
        answers: _with(step.id, answer ?? true),
        skipped: {...state.skipped}..remove(step.id),
        lastAnsweredId: () => step.id,
        error: () => null,
      );
    }
    _advance();
    await _persist();
    return true;
  }

  /// Stores an answer for the current step without moving (drafts that should
  /// survive a restart, e.g. the pledge timestamp).
  Future<void> record(Object? answer) async {
    final step = state.current;
    state = state.copyWith(answers: _with(step.id, answer), lastAnsweredId: () => step.id);
    await _persist();
  }

  Future<void> skip() async {
    final step = state.current;
    if (!step.skippable) return;
    final answers = Map<String, Object?>.of(state.answers)..remove(step.id);
    state = state.copyWith(
      answers: Map.unmodifiable(answers),
      skipped: {...state.skipped, step.id},
      lastAnsweredId: () => step.id,
      error: () => null,
    );
    _advance();
    await _persist();
  }

  Future<void> back() async {
    if (state.isEditing) {
      // Cancel the edit: go straight back to where the user was.
      state = state.copyWith(currentId: state.returnToId, returnToId: () => null, error: () => null);
    } else {
      final visible = state.visibleSteps;
      final i = state.index;
      if (i <= 0) return;
      state = state.copyWith(currentId: visible[i - 1].id, error: () => null);
    }
    await _persist();
  }

  /// Tapping a profile.doji line: jump to its step, remember where we were.
  Future<void> editFromConfig(String stepId) async {
    if (stepId == state.currentId) return;
    if (!state.steps.any((s) => s.id == stepId && s.isVisible(state.answers))) return;
    state = state.copyWith(
      currentId: stepId,
      returnToId: () => state.returnToId ?? state.currentId,
      error: () => null,
    );
    await _persist();
  }

  Future<void> goTo(String stepId) async {
    state = state.copyWith(currentId: stepId, returnToId: () => null, error: () => null);
    await _persist();
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: () => null);
  }

  void _advance() {
    final visible = state.visibleSteps;
    final i = visible.indexWhere((s) => s.id == state.currentId);
    final next = i >= 0 && i + 1 < visible.length ? visible[i + 1] : null;
    final returnTo = state.returnToId;
    if (returnTo != null) {
      // Conditional steps are follow-ups of the step before them (e.g. the
      // parsed strategy after editing the description): visit them first.
      if (next != null && next.condition != null && next.id != returnTo) {
        state = state.copyWith(currentId: next.id);
        return;
      }
      final stillVisible = visible.any((s) => s.id == returnTo);
      state = state.copyWith(
        currentId: stillVisible ? returnTo : (next?.id ?? state.currentId),
        returnToId: () => null,
      );
      return;
    }
    if (next != null) state = state.copyWith(currentId: next.id);
  }

  // --- step-specific actions ----------------------------------------------

  /// "read it": store the description, run the parser (the blinking cursor is
  /// the only loading state), then show the structured result.
  Future<bool> submitStrategy(Map<String, Object?> strategy) async {
    final step = state.current;
    final error = step.validate?.call(strategy);
    if (error != null) {
      state = state.copyWith(error: () => error);
      return false;
    }
    final raw = A.mapStr(strategy, 'raw');
    final template = A.mapStr(strategy, 'template');
    ParsedStrategy? parsed;
    if (raw != null) {
      state = state.copyWith(parsing: true, error: () => null);
      try {
        parsed = await ref.read(strategyParserProvider).parse(raw);
      } on Object {
        parsed = null; // parser failed: the review step starts empty but editable
      }
      if (!ref.mounted) return false;
      state = state.copyWith(parsing: false);
    } else if (template != null && template != 'none') {
      parsed = strategyTemplates[template];
    }
    var answers = _with(step.id, strategy);
    if (parsed != null) {
      answers = Map.unmodifiable({...answers, StepIds.strategyParsed: _parsedJson(parsed)});
    }
    state = state.copyWith(
      answers: answers,
      skipped: {...state.skipped}..remove(step.id),
      lastAnsweredId: () => step.id,
      error: () => null,
    );
    _advance();
    await _persist();
    return true;
  }

  Future<void> setTimeZone(Map<String, Object?> tz) async {
    state = state.copyWith(answers: _with(StepIds.timeZone, tz));
    await _persist();
  }

  Future<void> completePledge(DateTime at) => record({'pledgedAt': at.toUtc().toIso8601String()});

  /// Save-your-setup → "continue without account": keep the profile on this
  /// device, flagged for sync once the user signs in.
  Future<ProfileDoji> finishLocally() async {
    final profile = state.profile.copyWith(
      pendingSync: true,
      completedAt: DateTime.now().toUtc(),
      onboardingVersion: ProfileDoji.currentOnboardingVersion,
    );
    await _repo.saveProfile(profile);
    await _repo.clearSnapshot();
    return profile;
  }

  /// Development helper: forget everything and start from boot.
  Future<void> reset() async {
    await _repo.clearAll();
    state = OnboardingState(steps: state.steps, currentId: state.steps.first.id, answers: const {});
    await _detectTimeZone();
  }

  // --- helpers ---------------------------------------------------------------

  Answers _with(String key, Object? value) => Map.unmodifiable({...state.answers, key: value});

  static Map<String, Object?> _parsedJson(ParsedStrategy p) => {
    if (p.setup != null) 'setup': p.setup,
    if (p.timeframe != null) 'timeframe': p.timeframe,
    if (p.entry != null) 'entry': p.entry,
    if (p.stop != null) 'stop': p.stop,
    if (p.target != null) 'target': p.target,
  };

  Future<void> _persist() => _repo.saveSnapshot(
    OnboardingSnapshot(
      currentStepId: state.currentId,
      answers: state.answers,
      skipped: state.skipped,
      returnToStepId: state.returnToId,
      lastAnsweredStepId: state.lastAnsweredId,
      version: ProfileDoji.currentOnboardingVersion,
      updatedAt: DateTime.now().toUtc(),
    ),
  );
}

/// The script, overridable in tests.
final onboardingStepsProvider = Provider<List<OnboardingStep>>((ref) => buildOnboardingSteps());

final onboardingControllerProvider = NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
