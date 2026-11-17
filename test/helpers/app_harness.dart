import 'dart:convert';

import 'package:doji_app/app/app.dart';
import 'package:doji_app/app/router.dart';
import 'package:doji_app/features/onboarding/domain/strategy_parser.dart';
import 'package:doji_app/core/widgets/auth_method_button.dart';
import 'package:doji_app/features/auth/data/consent_repository.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/features/auth/domain/auth_repository.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'sample_profile.dart';

/// The whole app (router, app-lock gate, text clamp) at [location], with
/// every platform service faked. Reduce motion is on unless [reduced] is
/// false, so typing is instant and cursors are solid.
///
/// Pass `variant: ios` (or another [TargetPlatformVariant]) to the test:
/// PlatformInfo reads the global target platform.
class AppHarness {
  AppHarness._(this.tester, this.container, this.prefs, this.haptics, this.biometric, this.reminders);

  final WidgetTester tester;
  final ProviderContainer container;
  final SharedPreferences prefs;
  final RecordingHaptics haptics;
  final FakeBiometricAuth biometric;
  final FakeReminders reminders;

  bool online = true;

  GoRouter get router => container.read(routerProvider);

  /// The top route, pushed ones included.
  String get location => router.routerDelegate.currentConfiguration.last.matchedLocation;

  static Future<AppHarness> pump(
    WidgetTester tester, {
    required String at,
    Map<String, Object> seed = const {},
    Size size = const Size(390, 844),
    bool reduced = true,
    double textScale = 1,
    FakeBiometricAuth? biometric,
    FakeVoiceInput? voice,
    FakeReminders? reminders,
    MarketData? market,
    StrategyParser? parser,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (reduced) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    final haptics = RecordingHaptics();
    final bio = biometric ?? FakeBiometricAuth();
    final notes = reminders ?? FakeReminders();
    late final AppHarness h;
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(
          prefs,
          haptics: haptics,
          biometric: bio,
          isOnline: () => h.online,
          voice: voice,
          reminders: notes,
          market: market,
          parser: parser,
        ),
        ...overrides,
        routerProvider.overrideWith((ref) {
          final r = buildRouter(initialLocation: at);
          ref.onDispose(r.dispose);
          return r;
        }),
      ],
    );
    addTearDown(container.dispose);
    h = AppHarness._(tester, container, prefs, haptics, bio, notes);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const DojiApp()));
    await h.wait(100);
    return h;
  }

  /// Pumps 16ms frames for [ms]. pumpAndSettle never settles: cursors blink.
  Future<void> wait([int ms = 300]) async {
    for (var t = 0; t < ms; t += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> tap(Finder f, {int settle = 300}) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await wait(settle);
  }

  Future<void> tapText(String text, {int settle = 300}) => tap(find.text(text).last, settle: settle);
}

/// The handoff is drawn for iPhone; most flows run as iOS.
final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// A finished profile.doji on this device.
Map<String, Object> seedProfile({ProfileDoji? profile, bool pendingSync = true}) => {
  PrefsOnboardingRepository.profileKey: jsonEncode(
    (profile ??
            profileWith(
              name: 'sam',
              style: 'day_trader',
              instruments: const ['XAUUSD', 'NAS100'],
              pledgedAt: DateTime.utc(2026, 10, 1),
              completedAt: DateTime.utc(2026, 10, 1),
            ))
        .copyWith(pendingSync: pendingSync)
        .toJson(),
  ),
};

/// Signed in with the sample Google account.
Map<String, Object> seedSession({String email = 'google.user@example.com'}) => {
  FakeAuthRepository.sessionKey: jsonEncode(
    AuthUser(id: 'google:sample', method: AuthMethod.google, email: email).toJson(),
  ),
  FakeAuthRepository.accountsKey: jsonEncode({
    'google:sample': {'method': 'google', 'email': email, 'profile': null},
  }),
};

/// A7 already agreed for [userId] on this device.
Map<String, Object> seedConsent(String userId) => {
  ConsentRepository.key: jsonEncode({'userId': userId, 'pending': false, 'version': kConsentVersion}),
};

/// A6: a guest setup paused on "save your setup", and the sample Google
/// account (signed out) already holding its own setup.
Map<String, Object> seedSetupConflict(Map<String, Object> resumeAtSave) => {
  ...resumeAtSave,
  FakeAuthRepository.accountsKey: jsonEncode({
    'google:sample': {
      'method': 'google',
      'email': 'google.user@example.com',
      'profile': jsonDecode(seedProfile(pendingSync: false)[PrefsOnboardingRepository.profileKey]! as String),
    },
  }),
  ...seedConsent('google:sample'),
};
