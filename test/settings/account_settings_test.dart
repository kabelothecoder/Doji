// Auth handoff A11 (sign out) and A12a – A12d (delete account).
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/widgets/widgets.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/features/auth/presentation/auth_controller.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/settings/presentation/delete_account_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

DojiButton _button(WidgetTester tester, String label) =>
    tester.widget<DojiButton>(find.widgetWithText(DojiButton, label));

void main() {
  testWidgets('Home → settings shows the account', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.home, seed: {...seedProfile(), ...seedSession()});
    await h.tap(find.bySemanticsLabel('me'));
    await h.tapText('account and settings');
    expect(h.location, Routes.settings);
    expect(find.text('google.user@example.com'), findsOneWidget);
    expect(find.text('sign out'), findsOneWidget);
    expect(find.text('delete account'), findsOneWidget);
  }, variant: ios);

  testWidgets('signed out: settings offers sign in instead of sign out / delete', (tester) async {
    await AppHarness.pump(tester, at: Routes.settings, seed: seedProfile());
    expect(find.text('on this device only'), findsOneWidget);
    expect(find.text('sign in to sync'), findsOneWidget);
    expect(find.text('delete account'), findsNothing);
  }, variant: ios);

  testWidgets('A11: sign out sheet; cancel keeps everything, sign out forgets this device', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.settings, seed: {...seedProfile(), ...seedSession()});
    await h.tapText('sign out');
    expect(find.text('sign out of doji?'), findsOneWidget);
    await h.tapText('cancel');
    expect(find.text('sign out of doji?'), findsNothing);
    expect(h.container.read(authSessionProvider), isNotNull);

    await h.tapText('sign out');
    await h.tap(find.widgetWithText(DojiButton, 'sign out'));
    expect(h.container.read(authSessionProvider), isNull);
    expect(h.container.read(onboardingRepositoryProvider).loadProfile(), isNull);
    expect(h.prefs.getString(FakeAuthRepository.accountsKey), contains('google:sample'));
  }, variant: ios);

  testWidgets('A12: explain → type delete → final alert → done → splash as a new install', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.settings, seed: {...seedProfile(), ...seedSession()});
    await h.tapText('delete account');
    expect(find.text('delete your account.'), findsOneWidget);
    expect(find.textContaining('google.user@example.com'), findsOneWidget);
    for (final (_, item) in DeleteExplainScreen.items) {
      expect(find.text(item), findsOneWidget);
    }
    expect(find.textContaining('App Store'), findsOneWidget, reason: 'billing note on iOS');

    await h.tapText('continue');
    expect(_button(tester, 'delete account').onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'delet');
    await h.wait(50);
    expect(_button(tester, 'delete account').onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Delete ');
    await h.wait(50);
    expect(_button(tester, 'delete account').onPressed, isNotNull);

    // Final alert: cancel is the safe default.
    await h.tapText('delete account');
    expect(find.text('delete permanently?'), findsOneWidget);
    await h.tapText('cancel');
    expect(h.container.read(authSessionProvider), isNotNull);

    await h.tapText('delete account');
    await h.tap(find.widgetWithText(DojiPressable, 'delete'), settle: 400);
    expect(h.location, Routes.accountDeleted);
    expect(find.text('your data is gone.'), findsOneWidget);
    expect(h.container.read(authSessionProvider), isNull);
    expect(h.container.read(onboardingRepositoryProvider).loadProfile(), isNull);
    expect(h.prefs.getString(FakeAuthRepository.accountsKey), isNot(contains('google:sample')));

    // Splash, then onboarding from the start, as on a new install.
    await h.tapText('done', settle: 2000);
    expect(h.location, Routes.onboarding);
  }, variant: ios);

  testWidgets('A12 offline: nothing is deleted and the line says so', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.deleteConfirm,
      seed: {...seedProfile(), ...seedSession()},
    );
    h.online = false;
    await tester.enterText(find.byType(TextField), 'delete');
    await h.wait(50);
    await h.tapText('delete account');
    await h.tap(find.widgetWithText(DojiPressable, 'delete'), settle: 300);
    expect(find.textContaining('connection lost. nothing was deleted. try again.'), findsOneWidget);
    expect(h.container.read(authSessionProvider), isNotNull);
  }, variant: ios);

  test('type-to-confirm: trimmed, any case', () {
    expect(DeleteConfirmScreen.matches(' DELETE '), isTrue);
    expect(DeleteConfirmScreen.matches('delete account'), isFalse);
  });
}
