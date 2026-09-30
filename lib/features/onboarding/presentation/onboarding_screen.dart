import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/platform/connectivity.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/device_services.dart';
import '../domain/onboarding_catalog.dart';
import '../domain/onboarding_step.dart';
import '../domain/sessions.dart';
import 'onboarding_controller.dart';
import 'step_drafts.dart';
import 'steps/choice_inputs.dart';
import 'steps/coach_inputs.dart';
import 'steps/plan_inputs.dart';
import 'steps/special_steps.dart';
import 'steps/step_input.dart';
import 'steps/text_inputs.dart';

/// Breakpoints: side pane from 1100px (Windows handoff is 1440 × 900),
/// centred 720px column from 600px, full width below.
abstract final class OnboardingLayout {
  static const wide = 1100.0;
  static const medium = 600.0;
  static const column = 720.0;
  static const pane = 520.0;
}

/// The terminal conversation. One screen, driven entirely by the step
/// catalogue through [OnboardingController].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _typing = TypingSkipController();
  final _screenFocus = FocusNode(debugLabel: 'onboarding');
  final _firstConfigLine = FocusNode(debugLabel: 'profile.doji line 1');

  String? _draftStep;
  Object? _draft;
  bool _replyDone = false;
  bool _typed = false;
  bool _compiled = false;
  bool _configCollapsed = false;
  bool _requesting = false;
  Timer? _autoAdvance;

  OnboardingController get _controller => ref.read(onboardingControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(onboardingControllerProvider).currentId == StepIds.save && mounted) {
        context.go(Routes.save);
      }
    });
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _typing.dispose();
    _screenFocus.dispose();
    _firstConfigLine.dispose();
    super.dispose();
  }

  void _syncStep(OnboardingState s) {
    if (_draftStep == s.currentId) return;
    _draftStep = s.currentId;
    _draft = initialDraft(s.current, s.answers);
    _replyDone = false;
    _typed = false;
    _compiled = s.answers.containsKey(StepIds.pledge);
    _autoAdvance?.cancel();
  }

  // --- actions ---------------------------------------------------------------

  void _onDraft(Object? draft, {bool advance = false}) {
    _controller.clearError();
    setState(() => _draft = draft);
    _autoAdvance?.cancel();
    if (advance) {
      _autoAdvance = Timer(DojiMotion.autoAdvance, () {
        if (mounted) unawaited(_primary());
      });
    }
  }

  Future<void> _primary() async {
    _autoAdvance?.cancel();
    _typing.skip();
    final s = ref.read(onboardingControllerProvider);
    final step = s.current;
    if (s.parsing || _requesting) return;
    switch (step.id) {
      case StepIds.strategy:
        await _controller.submitStrategy(_asMap(_draft));
      case StepIds.ritual:
        setState(() => _requesting = true);
        final result = await ref.read(notificationPermissionProvider).request();
        if (!mounted) return;
        setState(() => _requesting = false);
        await _controller.submit({..._asMap(_draft), 'notifications': result.name});
      case StepIds.pledge:
        if (s.answers.containsKey(StepIds.pledge)) await _controller.submit(s.answers[StepIds.pledge]);
      default:
        await _controller.submit(step.input == StepInput.info ? true : _draft);
    }
  }

  Future<void> _secondary() async {
    _autoAdvance?.cancel();
    final step = ref.read(onboardingControllerProvider).current;
    switch (secondaryFor(step)) {
      case SecondaryAction.signIn:
        unawaited(context.push(Routes.signIn));
      case SecondaryAction.skip:
        await _controller.skip();
      case SecondaryAction.declineNotifications:
        await _controller.submit({..._asMap(_draft), 'notifications': 'deferred'});
      case SecondaryAction.none:
        break;
    }
  }

  Future<void> _back() async {
    _autoAdvance?.cancel();
    await _controller.back();
  }

  Future<void> _editStep(String stepId) async {
    _autoAdvance?.cancel();
    await _controller.editFromConfig(stepId);
  }

  Future<void> _changeTimeZone() async {
    final current = ref.read(onboardingControllerProvider).answers[StepIds.timeZone];
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: DojiColors.elevated1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DojiRadius.sheet)),
      ),
      builder: (_) => _OffsetPicker(selected: (A.mapNum(current, 'offsetMinutes') ?? 0).round()),
    );
    if (picked == null) return;
    await _controller.setTimeZone({'id': utcLabel(picked), 'offsetMinutes': picked, 'detected': false});
  }

  static Map<String, Object?> _asMap(Object? d) =>
      d is Map ? d.map((k, v) => MapEntry(k.toString(), v)) : <String, Object?>{};

  // --- keyboard --------------------------------------------------------------

  bool get _focusInTextField =>
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (key == LogicalKeyboardKey.escape) {
      unawaited(_back());
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyE) {
      _firstConfigLine.requestFocus();
      return KeyEventResult.handled;
    }
    if (_focusInTextField) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      unawaited(_primary());
      return KeyEventResult.handled;
    }
    final digit = _digit(key);
    if (digit != null) {
      final s = ref.read(onboardingControllerProvider);
      _typing.skip();
      final next = pickOption(s.current, s.answers, _draft, digit - 1);
      if (next != null) _onDraft(next, advance: s.current.autoAdvance);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static int? _digit(LogicalKeyboardKey k) {
    const row = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const pad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = row.indexOf(k);
    if (i >= 0) return i + 1;
    final j = pad.indexOf(k);
    return j >= 0 ? j + 1 : null;
  }

  // --- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(onboardingControllerProvider);
    _syncStep(s);
    ref.listen(onboardingControllerProvider.select((x) => x.currentId), (prev, next) {
      if (next == StepIds.save && mounted) context.go(Routes.save);
    });
    final online = ref.watch(isOnlineProvider).value ?? true;

    return PopScope(
      canPop: s.isFirst && !s.isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: DojiColors.bg,
        resizeToAvoidBottomInset: true,
        body: Focus(
          focusNode: _screenFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: TypingScope(
            controller: _typing,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _typing.skip,
              excludeFromSemantics: true,
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= OnboardingLayout.wide;
                  final body = _StepChrome(
                    state: s,
                    wide: wide,
                    online: online,
                    configCollapsed: _configCollapsed,
                    onToggleConfig: () => setState(() => _configCollapsed = !_configCollapsed),
                    onEditLine: (l) => _editStep(l.targetId),
                    firstConfigLine: _firstConfigLine,
                    onBack: _back,
                    content: _content(s, wide),
                    footer: _footer(s, wide),
                  );
                  final grain =
                      s.current.view == StepView.boot ||
                      s.current.view == StepView.manifesto ||
                      s.current.view == StepView.pledge;
                  return Stack(
                    children: [
                      if (grain) const Positioned.fill(child: GrainOverlay()),
                      if (PlatformInfo.isIOS) _EdgeSwipeBack(onBack: s.isFirst ? null : _back),
                      body,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(OnboardingState s, bool wide) {
    final step = s.current;
    final Widget child = switch (step.view) {
      StepView.boot => BootStepView(wide: wide),
      StepView.manifesto => const ManifestoStepView(),
      StepView.compile => CompileStepView(
        lines: s.configLines,
        profile: s.profile,
        onCompiled: () => setState(() => _compiled = true),
      ),
      StepView.pledge => PledgeStepView(
        wide: wide,
        pledged: s.answers.containsKey(StepIds.pledge),
        onPledged: () => _controller.completePledge(DateTime.now()),
      ),
      StepView.question => _question(s, wide),
      StepView.save => const SizedBox.shrink(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(step.id), child: child),
    );
  }

  Widget _question(OnboardingState s, bool wide) {
    final step = s.current;
    final reply = s.reply;
    final hasReply = reply != null && reply.isNotEmpty;
    final reduced = DojiMotion.reduced(context);
    final args = StepInputArgs(
      step: step,
      answers: s.answers,
      draft: _draft,
      onChanged: _onDraft,
      onSubmit: () => unawaited(_primary()),
      wide: wide,
      hasError: s.error != null,
    );
    final Widget input = switch (step.id) {
      StepIds.name => TextAnswerInput(args, helper: 'a nickname is fine. you can change it anytime.'),
      StepIds.experience || StepIds.style => SingleChoiceInput(args),
      StepIds.markets || StepIds.struggles => MultiChoiceInput(args),
      StepIds.sessions => MultiChoiceInput(args, onChangeTimeZone: _changeTimeZone),
      StepIds.goal => GoalInput(args),
      StepIds.strategy => StrategyInput(args, parsing: s.parsing),
      StepIds.strategyParsed => ParsedStrategyInput(args),
      StepIds.risk => RiskInput(args),
      StepIds.rules => RulesCard(answers: s.answers, onEditStep: _editStep),
      StepIds.coach => CoachInput(args),
      StepIds.ritual => RitualInput(args),
      _ => const SizedBox.shrink(),
    };

    final conversation = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasReply) ...[
          TypingText(
            reply,
            style: wide ? DojiType.replyWide : DojiType.reply,
            showCursor: false,
            onDone: () => setState(() => _replyDone = true),
          ),
          SizedBox(height: wide ? 18 : 14),
        ],
        TypingText(
          step.prompt,
          start: !hasReply || _replyDone,
          style: wide ? DojiType.questionWide : DojiType.question,
          onDone: () => setState(() => _typed = true),
        ),
        if (step.sub != null) ...[
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: _typed || reduced ? 1 : 0,
            duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
            child: Text(step.sub!, style: DojiType.callout),
          ),
        ],
        if (s.error != null) ...[
          const SizedBox(height: 12),
          TerminalLine(s.error!, tone: TerminalTone.tilt, cursor: true),
        ],
      ],
    );

    final revealed = _typed || reduced;
    return FillScroll(
      children: [
        conversation,
        SizedBox(height: wide ? 24 : 16),
        IgnorePointer(
          ignoring: !revealed,
          child: AnimatedOpacity(
            opacity: revealed ? 1 : 0,
            duration: reduced ? Duration.zero : const Duration(milliseconds: 240),
            child: input,
          ),
        ),
      ],
    );
  }

  Widget? _footer(OnboardingState s, bool wide) {
    final step = s.current;
    if (step.view == StepView.save) return null;
    final pledged = s.answers.containsKey(StepIds.pledge);
    if (step.view == StepView.pledge && !pledged) return null;
    final secondary = secondaryFor(step);
    final busy = s.parsing || _requesting;
    final cta = s.isEditing && step.view == StepView.question ? 'save' : step.cta;

    final primary = DojiButton(
      label: busy ? '…' : cta,
      onPressed: busy || (step.view == StepView.compile && !_compiled) ? null : () => unawaited(_primary()),
      size: wide ? DojiButtonSize.regular : DojiButtonSize.large,
      expand: !wide,
      autofocus: step.view == StepView.pledge,
    );
    final secondaryButton = secondary == SecondaryAction.none
        ? null
        : DojiButton(
            label: step.skipLabel,
            variant: DojiButtonVariant.text,
            size: DojiButtonSize.small,
            expand: !wide,
            onPressed: busy ? null : () => unawaited(_secondary()),
          );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          primary,
          if (secondaryButton != null) ...[const SizedBox(height: 4), secondaryButton],
        ],
      );
    }
    final n = step.resolveOptions(s.answers).length;
    return Row(
      children: [
        primary,
        if (secondaryButton != null) ...[const SizedBox(width: 16), secondaryButton],
        const Spacer(),
        Flexible(
          child: KeyHints([
            if (n > 1 && step.view == StepView.question) '1–${n.clamp(1, 9)} pick',
            '↵ continue',
            if (!s.isFirst) 'esc back',
          ]),
        ),
      ],
    );
  }
}

/// Header, config panel / pane, offline line, content and footer, laid out
/// for phone, centred column, or the Windows side pane.
class _StepChrome extends StatelessWidget {
  const _StepChrome({
    required this.state,
    required this.wide,
    required this.online,
    required this.configCollapsed,
    required this.onToggleConfig,
    required this.onEditLine,
    required this.firstConfigLine,
    required this.onBack,
    required this.content,
    required this.footer,
  });

  final OnboardingState state;
  final bool wide;
  final bool online;
  final bool configCollapsed;
  final VoidCallback onToggleConfig;
  final ValueChanged<ConfigLineData> onEditLine;
  final FocusNode firstConfigLine;
  final VoidCallback onBack;
  final Widget content;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final step = state.current;
    final lines = state.configLines;
    final showHeader = step.view != StepView.manifesto;
    final showProgress = step.view != StepView.boot && step.view != StepView.manifesto;
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final showBack = !state.isFirst && (PlatformInfo.isAndroid || PlatformInfo.isDesktop) && showHeader;

    final headerHeight = DojiTokens.of(context).minTarget; // 44pt, 48dp on Android
    final header = !showHeader
        ? SizedBox(height: headerHeight)
        : SizedBox(
            height: headerHeight,
            child: Row(
              children: [
                if (showBack) ...[
                  Transform.translate(
                    offset: const Offset(-10, 0),
                    child: DojiIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: 'Back',
                      background: Colors.transparent,
                      onPressed: onBack,
                    ),
                  ),
                ],
                const WordmarkHero(child: DojiWordmark(size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: showProgress
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: ProgressBarTerminal(
                            fraction: state.progress,
                            style: wide ? DojiType.hint.copyWith(fontSize: 13) : null,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );

    final offline = online
        ? null
        : const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: TerminalLine(
              'connection lost. your answers are saved.',
              tone: TerminalTone.tilt,
              cursor: true,
            ),
          );

    final compactConfig = step.showConfig && lines.isNotEmpty && !wide
        ? Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ConfigPanel(
              lines: lines,
              totalLines: state.totalLines,
              collapsed: configCollapsed,
              visibleLines: step.configWindow,
              onToggleCollapsed: onToggleConfig,
              onEditLine: onEditLine,
              firstLineFocusNode: firstConfigLine,
            ),
          )
        : null;

    // Header and profile.doji stay put; only the step content scrolls
    // (FillScroll inside each step view).
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?offline,
        ?compactConfig,
        Expanded(child: content),
      ],
    );

    if (wide) {
      final showPane = step.view != StepView.boot && step.view != StepView.manifesto;
      return SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = ((c.maxWidth - OnboardingLayout.column) / 2).clamp(32.0, 120.0);
                  return Padding(
                    padding: EdgeInsets.fromLTRB(side, 24, side, 48),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: OnboardingLayout.column),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,
                            const SizedBox(height: 24),
                            Expanded(child: body),
                            if (footer != null) ...[const SizedBox(height: 24), footer!],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (showPane)
              SizedBox(
                width: OnboardingLayout.pane,
                child: ConfigPanel(
                  layout: ConfigPanelLayout.pane,
                  lines: lines,
                  totalLines: state.totalLines,
                  onEditLine: onEditLine,
                  firstLineFocusNode: firstConfigLine,
                ),
              ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: OnboardingLayout.column),
          child: Padding(
            padding: EdgeInsets.fromLTRB(margin, 8, margin, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 16),
                Expanded(child: body),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS has no back button in the handoff: swipe from the left edge instead.
class _EdgeSwipeBack extends StatelessWidget {
  const _EdgeSwipeBack({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: 20,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: onBack == null
          ? null
          : (d) {
              if ((d.primaryVelocity ?? 0) > 300) onBack!();
            },
    ),
  );
}

/// "change" on the time zone row: searchable list of UTC offsets. Offsets,
/// not IANA ids, because session opens only need the offset (see sessions.dart).
class _OffsetPicker extends StatefulWidget {
  const _OffsetPicker({required this.selected});

  final int selected;

  @override
  State<_OffsetPicker> createState() => _OffsetPickerState();
}

class _OffsetPickerState extends State<_OffsetPicker> {
  final _q = TextEditingController();
  static final _offsets = [
    for (var m = -12 * 60; m <= 14 * 60; m += 30) m,
    345, // UTC+5:45
  ]..sort();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toUpperCase().replaceAll(' ', '');
    final items = _offsets.where((m) => utcLabel(m).contains(q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TerminalLine('pick your offset from UTC.', tone: TerminalTone.primary), // doji voice
              const SizedBox(height: 12),
              DojiTextField(
                controller: _q,
                large: false,
                hint: 'search, e.g. +2',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i];
                    final selected = m == widget.selected;
                    return DojiPressable(
                      onPressed: () => Navigator.of(context).pop(m),
                      selected: selected,
                      semanticLabel: utcLabel(m),
                      borderRadius: BorderRadius.circular(DojiRadius.chip),
                      child: Container(
                        constraints: BoxConstraints(minHeight: DojiTokens.of(context).minTarget),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: selected ? DojiColors.greenTint : Colors.transparent,
                          borderRadius: BorderRadius.circular(DojiRadius.chip),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(utcLabel(m), style: DojiType.data)),
                            if (selected)
                              const Icon(Icons.check_rounded, color: DojiColors.dojiGreen, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
