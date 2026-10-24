// Goldens for the auth handoff (design/handoff/Doji Auth Screen iOS.dc.html)
// on iPhone 390 × 844, plus A1 on Windows 1440 × 900.
//
//   flutter test test/goldens --update-goldens   # after an intended change
//
// Reduce motion is on, so typing is complete and cursors are solid.
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/app_lock/data/app_lock_repository.dart';
import 'package:doji_app/features/app_lock/data/biometric_auth.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

Future<void> _match(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('auth_$name.png'));

Future<AppHarness> _toCode(WidgetTester tester) async {
  final h = await AppHarness.pump(tester, at: Routes.signIn);
  await h.tapText('continue with email');
  await tester.enterText(find.byType(TextField), 'sam@example.com');
  await h.wait(50);
  await h.tapText('send code', settle: 200);
  return h;
}

void main() {
  testWidgets('A1 welcome back', (tester) async {
    await AppHarness.pump(tester, at: Routes.signIn);
    await _match('a1_welcome_phone');
  }, variant: ios);

  testWidgets('A1 welcome back · windows', (tester) async {
    await AppHarness.pump(tester, at: Routes.signIn, size: const Size(1440, 900));
    await _match('a1_welcome_windows');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('A2 save your setup', (tester) async {
    await AppHarness.pump(tester, at: Routes.save, seed: resumeAt(StepIds.save));
    await _match('a2_save_phone');
  }, variant: ios);

  testWidgets('A4b wrong code', (tester) async {
    final h = await _toCode(tester);
    final input = find.descendant(of: find.byType(OtpCodeField), matching: find.byType(TextField));
    await tester.enterText(input, FakeAuthRepository.wrongCode);
    await h.wait(200);
    FocusManager.instance.primaryFocus?.unfocus();
    await h.wait(50);
    await _match('a4b_wrong_phone');
  }, variant: ios);

  testWidgets('A9 authenticated', (tester) async {
    final h = await _toCode(tester);
    final input = find.descendant(of: find.byType(OtpCodeField), matching: find.byType(TextField));
    await tester.enterText(input, '482913');
    await h.wait(200);
    await _match('a9_success_phone');
  }, variant: ios);

  // The lock blurs the live Home behind it, and Home follows the clock (the
  // grid's today, evening mode, market hours): pin the day.
  testWidgets('A8b locked', (tester) async {
    await withClock(summerDay, () async {
      await AppHarness.pump(
        tester,
        at: Routes.home,
        seed: {...seedProfile(), AppLockRepository.enabledKey: true},
        biometric: FakeBiometricAuth(result: BiometricResult.cancelled),
      );
      await _match('a8b_locked_phone');
    });
  }, variant: ios);

  testWidgets('A12a delete · what goes', (tester) async {
    await AppHarness.pump(tester, at: Routes.deleteAccount, seed: {...seedProfile(), ...seedSession()});
    await _match('a12a_delete_phone');
  }, variant: ios);
}
