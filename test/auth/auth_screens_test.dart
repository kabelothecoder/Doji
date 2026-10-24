// Auth handoff A1 – A10 through the real router and app shell.
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/sample_profile.dart';

Finder _line(String text) => find.textContaining(text);

/// The hidden field behind the six boxes.
Finder get _codeInput => find.descendant(of: find.byType(OtpCodeField), matching: find.byType(TextField));

DojiButton _button(WidgetTester tester, String label) =>
    tester.widget<DojiButton>(find.widgetWithText(DojiButton, label));

Future<void> _toCodeScreen(AppHarness h, {String email = 'sam@example.com'}) async {
  await h.tapText('continue with email');
  expect(find.text("what's your email?"), findsOneWidget);
  await h.tester.enterText(find.byType(TextField), email);
  await h.wait(50);
  await h.tapText('send code', settle: 200);
  expect(find.text('check your email.'), findsOneWidget);
}

void main() {
  testWidgets('A1 → A3 → A4 → A9 → Home: email code, success types in, haptic, hand-off', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn, seed: seedProfile());
    expect(find.text('welcome back.'), findsOneWidget);
    // Same order everywhere: Apple, Google, email.
    final labels = tester.widgetList<AuthMethodButton>(find.byType(AuthMethodButton)).map((b) => b.label);
    expect(labels, ['Sign in with Apple', 'Sign in with Google', 'continue with email']);

    await _toCodeScreen(h);
    expect(find.textContaining('sam@example.com'), findsOneWidget);
    await tester.enterText(_codeInput, '482913');
    await h.wait(200);

    expect(h.location, Routes.authenticated);
    expect(_line('creating account… ok'), findsOneWidget);
    expect(_line('saving profile.doji… ok'), findsOneWidget);
    expect(_line('authenticated.'), findsOneWidget);
    expect(_line('→ opening home'), findsOneWidget);
    expect(h.haptics.events, contains('success'));

    await h.wait(3600);
    expect(h.location, Routes.home);
    expect(find.text('DOJI SCORE'), findsOneWidget);
    final saved = h.container.read(onboardingRepositoryProvider).loadProfile()!;
    expect(saved.pendingSync, isFalse, reason: 'uploaded to the account');
  }, variant: ios);

  testWidgets('A3: send is disabled until the value looks like an email', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await h.tapText('continue with email');
    expect(_button(tester, 'send code').onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'sam@example');
    await h.wait(50);
    expect(_button(tester, 'send code').onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'sam@example.com');
    await h.wait(50);
    expect(_button(tester, 'send code').onPressed, isNotNull);
    // Return also sends.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await h.wait(200);
    expect(find.text('check your email.'), findsOneWidget);
  }, variant: ios);

  testWidgets('A4b: wrong code turns orange with attempts left; the next keystroke clears it', (
    tester,
  ) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await _toCodeScreen(h);
    await tester.enterText(_codeInput, FakeAuthRepository.wrongCode);
    await h.wait(200);
    expect(_line("that code didn't match. 4 tries left."), findsOneWidget);
    expect(tester.widget<OtpCodeField>(find.byType(OtpCodeField)).state, OtpFieldState.wrong);

    // Typing into the full field starts a new code.
    await tester.enterText(_codeInput, '${FakeAuthRepository.wrongCode}4');
    await h.wait(50);
    expect(_line("that code didn't match"), findsNothing);
    expect(tester.widget<TextField>(_codeInput).controller!.text, '4');
  }, variant: ios);

  testWidgets('A4c: an expired code locks the field; the only action is a new code', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await _toCodeScreen(h);
    await tester.enterText(_codeInput, FakeAuthRepository.expiredCode);
    await h.wait(200);
    expect(_line('that code expired. codes last 10 minutes.'), findsOneWidget);
    expect(tester.widget<OtpCodeField>(find.byType(OtpCodeField)).state, OtpFieldState.disabled);
    await h.tapText('send a new code', settle: 200);
    expect(_line('that code expired'), findsNothing);
    expect(find.textContaining('resend in'), findsOneWidget);
  }, variant: ios);

  testWidgets('A4d: five wrong codes lock for 15 minutes; another method stays available', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await _toCodeScreen(h);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(_codeInput, FakeAuthRepository.wrongCode);
      await h.wait(150);
      if (i < 4) {
        await tester.enterText(_codeInput, '');
        await h.wait(50);
      }
    }
    expect(_line('too many attempts. try again in 15:00.'), findsOneWidget);
    await h.wait(1300);
    expect(_line('try again in 15:00.'), findsNothing, reason: 'live countdown');
    expect(_line('try again in 14:5'), findsOneWidget);
    await h.tapText('use another method');
    expect(h.location, Routes.signIn);
    expect(find.text('welcome back.'), findsOneWidget);
  }, variant: ios);

  testWidgets('A4e: the 30s countdown becomes a resend link', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await _toCodeScreen(h);
    expect(find.text('resend in 0:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await h.wait(50);
    expect(find.text('resend code'), findsOneWidget);
    expect(find.text('nothing yet? check spam and promotions.'), findsOneWidget);
    await h.tapText('resend code', settle: 200);
    expect(find.text('resend in 0:30'), findsOneWidget);
  }, variant: ios);

  testWidgets('A4: paste takes the first 6 digits from any text and signs in', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'your doji code: 482 913'};
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await _toCodeScreen(h);
    await h.tapText('paste', settle: 200);
    expect(h.location, Routes.authenticated);
  }, variant: ios);

  testWidgets('A2b: waiting for apple; cancel returns with no error', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    await h.tapText('Sign in with Apple', settle: 30);
    expect(_line('waiting for apple…'), findsOneWidget);
    await h.tapText('cancel');
    expect(find.text('welcome back.'), findsOneWidget);
    await h.wait(200);
    expect(h.location, Routes.signIn);
    expect(find.byType(TerminalLine), findsNothing, reason: 'no error line');
  }, variant: ios);

  testWidgets('A2b → A9: Google returns, Home after the success lines', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn, seed: seedProfile());
    await h.tapText('Sign in with Google', settle: 300);
    expect(h.location, Routes.authenticated);
    expect(_line('creating account… ok'), findsOneWidget);
    await h.wait(3700);
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets('A10: connection lost; try again works once back online', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn);
    h.online = false;
    await h.tapText('Sign in with Apple');
    expect(_line('connection lost.'), findsOneWidget);
    expect(find.text('nothing was lost.'), findsOneWidget);
    expect(find.text('continue offline'), findsNothing, reason: 'no setup on this device');

    h.online = true;
    await h.tapText('try again', settle: 300);
    expect(h.location, Routes.authenticated);
    expect(_line('no profile.doji on this account yet'), findsOneWidget);
    expect(_line('→ opening setup'), findsOneWidget);
  }, variant: ios);

  testWidgets('A10 with a local setup offers continue offline', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.signIn, seed: seedProfile());
    h.online = false;
    await h.tapText('continue with email');
    await tester.enterText(find.byType(TextField), 'sam@example.com');
    await h.wait(50);
    await h.tapText('send code', settle: 200);
    expect(_line('connection lost.'), findsOneWidget);
    expect(find.text('nothing was lost. your setup is still on this device.'), findsOneWidget);
    await h.tapText('continue offline');
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets('A2: already signed in → the setup goes straight to the account', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.save,
      seed: {...seedSession(), ...resumeAt(StepIds.save)},
    );
    await h.wait(300);
    expect(h.location, Routes.authenticated);
    expect(_line('signed in… ok'), findsOneWidget);
    expect(_line('saving profile.doji…'), findsOneWidget);
  }, variant: ios);

  testWidgets('A2: continue without account → plans, then Home on continue free', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.save, seed: resumeAt(StepIds.save));
    await h.tapText('continue without account', settle: 500);
    expect(h.location, Routes.plans);
    expect(find.text('your doji is configured.'), findsOneWidget);
    await h.tapText('continue free');
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets('A2b → A9: saving to a new account hands off to plans', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.save, seed: resumeAt(StepIds.save));
    await h.tapText('Continue with Google', settle: 300);
    expect(h.location, Routes.authenticated);
    expect(_line('→ opening plans'), findsOneWidget);
    await h.wait(3700);
    expect(h.location, Routes.plans);
  }, variant: ios);
}
