// The accessibility floor (CLAUDE.md) on every auth, app-lock and settings
// screen: ≥ 44pt targets (48dp Android), labelled targets, ≥ 4.5:1 contrast,
// and 200% text without overflow.
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/app_lock/data/app_lock_repository.dart';
import 'package:doji_app/features/app_lock/data/biometric_auth.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

final _signedIn = {...seedProfile(), ...seedSession()};

/// Route → seed. The code screen is reached through A3 so it has a ticket.
final _screens = <String, Map<String, Object>>{
  Routes.signIn: const {},
  Routes.save: resumeAt(StepIds.save),
  Routes.email: const {},
  Routes.settings: _signedIn,
  Routes.appLock: _signedIn,
  Routes.deleteAccount: _signedIn,
  Routes.deleteConfirm: _signedIn,
  Routes.accountDeleted: const {},
};

void main() {
  for (final MapEntry(key: route, value: seed) in _screens.entries) {
    testWidgets('$route: tap targets, labels and contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await AppHarness.pump(tester, at: route, seed: seed);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    }, variant: ios);

    testWidgets('$route: 200% text scrolls instead of overflowing', (tester) async {
      await AppHarness.pump(tester, at: route, seed: seed, textScale: 2, size: const Size(375, 667));
      expect(tester.takeException(), isNull);
    }, variant: ios);
  }

  testWidgets('code entry: tap targets, labels, contrast and 200% text', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await AppHarness.pump(tester, at: Routes.signIn, textScale: 2, size: const Size(375, 667));
    await h.tapText('continue with email');
    await tester.enterText(find.byType(TextField), 'sam@example.com');
    await h.wait(50);
    await h.tapText('send code', settle: 200);
    expect(find.text('check your email.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp(r'6-digit code, 0 of 6 entered')), findsOneWidget);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }, variant: ios);

  testWidgets('lock screen: labelled unlock button, nothing underneath is reachable', (tester) async {
    final handle = tester.ensureSemantics();
    await AppHarness.pump(
      tester,
      at: Routes.home,
      seed: {...seedProfile(), AppLockRepository.enabledKey: true},
      biometric: FakeBiometricAuth(result: BiometricResult.cancelled),
    );
    expect(find.bySemanticsLabel('Unlock with Face ID'), findsOneWidget);
    expect(find.bySemanticsLabel('me'), findsNothing);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  }, variant: ios);

  testWidgets(
    'android: 48dp targets on sign-in and the code screen',
    (tester) async {
      final handle = tester.ensureSemantics();
      final h = await AppHarness.pump(tester, at: Routes.signIn, size: const Size(412, 915));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await h.tapText('continue with email');
      await tester.enterText(find.byType(TextField), 'sam@example.com');
      await h.wait(50);
      await h.tapText('send code', settle: 200);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
