import 'package:doji_app/app/routes.dart';
import 'package:doji_app/core/widgets/auth_method_button.dart';
import 'package:doji_app/features/app_lock/data/app_lock_repository.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/features/auth/presentation/auth_controller.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/domain/onboarding_catalog.dart';
import 'package:doji_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_profile.dart';

void main() {
  late SharedPreferences prefs;
  var online = true;

  /// A new process over the same storage.
  ProviderContainer fresh() {
    final c = ProviderContainer(overrides: testOverrides(prefs, isOnline: () => online));
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> start(Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    return fresh();
  }

  setUp(() => online = true);

  test('save your setup → the account gets this device\'s setup (A9b)', () async {
    final c = await start(resumeAt(StepIds.save));
    final lines = c.read(onboardingControllerProvider).configLines.length;
    expect(lines, greaterThan(5));

    final ok = await c.read(authFlowProvider.notifier).signInWith(AuthMethod.google, AuthIntent.save);
    expect(ok, isTrue);

    final outcome = c.read(authFlowProvider).outcome!;
    expect(outcome.statusLines, ['creating account… ok', 'saving profile.doji… $lines lines']);
    expect(outcome.welcomeName, isNull, reason: 'A9b: no name line');
    expect(outcome.destination, Routes.plans);

    final local = c.read(onboardingRepositoryProvider).loadProfile()!;
    expect(local.name, 'sam');
    expect(local.pendingSync, isFalse);
    expect(local.isComplete, isTrue);
    expect(c.read(onboardingRepositoryProvider).loadSnapshot(), isNull);
    expect(c.read(authSessionProvider)?.method, AuthMethod.google);
  });

  test('welcome back on a new device loads the account\'s setup (A9)', () async {
    final first = await start(resumeAt(StepIds.save));
    await first.read(authFlowProvider.notifier).signInWith(AuthMethod.google, AuthIntent.save);
    await first.read(accountActionsProvider).signOut();
    expect(first.read(onboardingRepositoryProvider).loadProfile(), isNull);

    final c = fresh();
    final ok = await c.read(authFlowProvider.notifier).signInWith(AuthMethod.google, AuthIntent.signIn);
    expect(ok, isTrue);
    final outcome = c.read(authFlowProvider).outcome!;
    expect(outcome.statusLines, ['verifying google account… ok', 'loading profile.doji… ok']);
    expect(outcome.welcomeName, 'sam');
    expect(outcome.destination, Routes.home);
    expect(c.read(onboardingRepositoryProvider).loadProfile()?.instruments, ['XAUUSD', 'NAS100']);
  });

  test('a brand-new account with no setup anywhere goes to onboarding', () async {
    final c = await start({});
    final flow = c.read(authFlowProvider.notifier)..setEmail('new@example.com');
    expect(await flow.sendCode(AuthIntent.signIn), isTrue);
    expect(await flow.verify('123456'), isTrue);
    final outcome = c.read(authFlowProvider).outcome!;
    expect(outcome.statusLines, ['creating account… ok', 'no profile.doji on this account yet']);
    expect(outcome.destination, Routes.onboarding);
  });

  test('wrong code → attempts left, and the next keystroke clears it', () async {
    final c = await start({});
    final flow = c.read(authFlowProvider.notifier)..setEmail('sam@example.com');
    await flow.sendCode(AuthIntent.signIn);
    expect(await flow.verify(FakeAuthRepository.wrongCode), isFalse);
    expect(c.read(authFlowProvider).codeStatus, CodeStatus.wrong);
    expect(c.read(authFlowProvider).attemptsLeft, 4);
    flow.codeEdited();
    expect(c.read(authFlowProvider).codeStatus, CodeStatus.idle);
  });

  test('offline → A10 state, nothing signed in', () async {
    final c = await start({});
    online = false;
    final ok = await c.read(authFlowProvider.notifier).signInWith(AuthMethod.apple, AuthIntent.signIn);
    expect(ok, isFalse);
    expect(c.read(authFlowProvider).offline, isTrue);
    expect(c.read(authFlowProvider).waitingFor, isNull);
    expect(c.read(authSessionProvider), isNull);
  });

  test('sign out forgets this device: profile, paused onboarding, app lock, session', () async {
    final c = await start(resumeAt(StepIds.save));
    await c.read(authFlowProvider.notifier).signInWith(AuthMethod.apple, AuthIntent.save);
    await AppLockRepository(prefs).setEnabled(true);

    await c.read(accountActionsProvider).signOut();
    expect(c.read(onboardingRepositoryProvider).loadProfile(), isNull);
    expect(c.read(onboardingRepositoryProvider).loadSnapshot(), isNull);
    expect(AppLockRepository(prefs).enabled, isFalse);
    expect(c.read(authSessionProvider), isNull);
    expect(
      prefs.getString(FakeAuthRepository.accountsKey),
      contains('apple:sample'),
      reason: 'the account stays',
    );
  });

  test('delete offline leaves everything in place', () async {
    final c = await start(resumeAt(StepIds.save));
    await c.read(authFlowProvider.notifier).signInWith(AuthMethod.apple, AuthIntent.save);
    online = false;
    await expectLater(c.read(accountActionsProvider).deleteAccount(), throwsA(anything));
    expect(c.read(onboardingRepositoryProvider).loadProfile(), isNotNull);
    expect(c.read(authSessionProvider), isNotNull);
  });

  test('mmss and remaining', () {
    expect(mmss(const Duration(seconds: 30)), '0:30');
    expect(mmss(const Duration(minutes: 14, seconds: 59)), '14:59');
    expect(mmss(const Duration(milliseconds: 200)), '0:01');
    expect(remaining(null), Duration.zero);
    expect(remaining(DateTime.now().subtract(const Duration(seconds: 1))), Duration.zero);
  });
}
