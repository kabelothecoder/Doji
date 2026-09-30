import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_step.dart';
import '../domain/profile_doji.dart';

/// Everything needed to resume onboarding exactly where the user left it.
@immutable
class OnboardingSnapshot {
  const OnboardingSnapshot({
    required this.currentStepId,
    required this.answers,
    this.skipped = const {},
    this.returnToStepId,
    this.lastAnsweredStepId,
    this.version = 1,
    this.updatedAt,
  });

  final String currentStepId;
  final Answers answers;
  final Set<String> skipped;

  /// Set while editing a line from profile.doji: where to go back to.
  final String? returnToStepId;
  final String? lastAnsweredStepId;
  final int version;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
    'version': version,
    'currentStepId': currentStepId,
    'answers': answers,
    'skipped': skipped.toList(),
    'returnToStepId': returnToStepId,
    'lastAnsweredStepId': lastAnsweredStepId,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static OnboardingSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final step = json['currentStepId'];
    final answers = json['answers'];
    if (step is! String || answers is! Map) return null;
    final skipped = json['skipped'];
    final updated = json['updatedAt'];
    return OnboardingSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      currentStepId: step,
      answers: answers.map((k, v) => MapEntry(k.toString(), v as Object?)),
      skipped: skipped is List ? skipped.whereType<String>().toSet() : const {},
      returnToStepId: json['returnToStepId'] as String?,
      lastAnsweredStepId: json['lastAnsweredStepId'] as String?,
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
    );
  }
}

/// Local-first store for pre-account onboarding and the finished profile.
abstract interface class OnboardingRepository {
  OnboardingSnapshot? loadSnapshot();
  Future<void> saveSnapshot(OnboardingSnapshot snapshot);
  Future<void> clearSnapshot();

  ProfileDoji? loadProfile();
  Future<void> saveProfile(ProfileDoji profile);
  Future<void> clearAll();
}

/// shared_preferences implementation. Reads are synchronous because the
/// instance is created once in bootstrap, so resume needs no loading state.
class PrefsOnboardingRepository implements OnboardingRepository {
  PrefsOnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const snapshotKey = 'doji.onboarding.v1';
  static const profileKey = 'doji.profile.v1';

  @override
  OnboardingSnapshot? loadSnapshot() {
    final raw = _prefs.getString(snapshotKey);
    if (raw == null) return null;
    try {
      return OnboardingSnapshot.fromJson(jsonDecode(raw));
    } on FormatException {
      return null; // corrupt: start fresh rather than crash on launch
    }
  }

  @override
  Future<void> saveSnapshot(OnboardingSnapshot snapshot) =>
      _prefs.setString(snapshotKey, jsonEncode(snapshot.toJson()));

  @override
  Future<void> clearSnapshot() => _prefs.remove(snapshotKey);

  @override
  ProfileDoji? loadProfile() {
    final raw = _prefs.getString(profileKey);
    if (raw == null) return null;
    try {
      return ProfileDoji.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveProfile(ProfileDoji profile) => _prefs.setString(profileKey, jsonEncode(profile.toJson()));

  @override
  Future<void> clearAll() async {
    await _prefs.remove(snapshotKey);
    await _prefs.remove(profileKey);
  }
}

/// Overridden in bootstrap with the real instance (and in tests with mocks).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in bootstrap'),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => PrefsOnboardingRepository(ref.watch(sharedPreferencesProvider)),
);
