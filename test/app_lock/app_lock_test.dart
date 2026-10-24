// Auth handoff A8a (setup) and A8b (lock on reopen).
import 'package:doji_app/app/routes.dart';
import 'package:doji_app/features/app_lock/data/app_lock_repository.dart';
import 'package:doji_app/features/app_lock/data/biometric_auth.dart';
import 'package:doji_app/features/app_lock/domain/biometric_kind.dart';
import 'package:doji_app/features/app_lock/presentation/app_lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';

Finder get _locked => find.textContaining('locked.');

void main() {
  testWidgets('A8a: turn on asks for Face ID once, then stays on', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.appLock);
    expect(find.text('lock doji with Face ID.'), findsOneWidget);
    expect(find.textContaining('asks when you open doji'), findsOneWidget);
    await h.tapText('turn on Face ID');
    expect(h.biometric.calls, hasLength(1));
    expect(h.biometric.calls.single.reason, AppLockController.reason);
    expect(AppLockRepository(h.prefs).enabled, isTrue);
  }, variant: ios);

  testWidgets('A8a: a failed check leaves it off and says so', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.appLock,
      biometric: FakeBiometricAuth(result: BiometricResult.failed),
    );
    await h.tapText('turn on Face ID');
    expect(find.textContaining("couldn't confirm it's you. try again."), findsOneWidget);
    expect(AppLockRepository(h.prefs).enabled, isFalse);
  }, variant: ios);

  testWidgets(
    'A8a names the method honestly on each platform',
    (tester) async {
      await AppHarness.pump(
        tester,
        at: Routes.appLock,
        biometric: FakeBiometricAuth(kind: BiometricKind.windowsHello),
      );
      expect(find.text('lock doji with Windows Hello.'), findsOneWidget);
      expect(find.text('turn on Windows Hello'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('A8a is offered once, on the second visit to Home', (tester) async {
    final h = await AppHarness.pump(tester, at: Routes.home, seed: seedProfile());
    expect(h.location, Routes.home);
    expect(AppLockRepository(h.prefs).homeVisits, 1);

    h.router.go(Routes.settings);
    await h.wait();
    h.router.go(Routes.home);
    await h.wait();
    expect(h.location, Routes.appLock);
    await h.tapText('not now');
    expect(h.location, Routes.home);

    h.router.go(Routes.settings);
    await h.wait();
    h.router.go(Routes.home);
    await h.wait();
    expect(h.location, Routes.home, reason: 'never asks again');
  }, variant: ios);

  testWidgets('no biometrics and no passcode: never offered, settings says unavailable', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.settings,
      seed: {...seedProfile(), AppLockRepository.homeVisitsKey: 5},
      biometric: FakeBiometricAuth()..kind = null,
    );
    expect(find.text('unavailable'), findsOneWidget);
    h.router.go(Routes.home);
    await h.wait();
    expect(h.location, Routes.home);
  }, variant: ios);

  testWidgets('A8b: locked on open; Face ID triggers automatically and unlocks', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.home,
      seed: {...seedProfile(), AppLockRepository.enabledKey: true},
      biometric: FakeBiometricAuth(results: [BiometricResult.cancelled]),
    );
    // The automatic attempt was cancelled: still locked, the button retries.
    expect(_locked, findsOneWidget);
    expect(h.biometric.calls, hasLength(1));
    expect(find.text('unlock with Face ID'), findsOneWidget);
    expect(find.text('use passcode'), findsOneWidget);

    await h.tapText('unlock with Face ID');
    expect(_locked, findsNothing);
    expect(find.text('DOJI SCORE'), findsOneWidget);
  }, variant: ios);

  testWidgets('A8b: a device with no lock left never traps the user', (tester) async {
    await AppHarness.pump(
      tester,
      at: Routes.home,
      seed: {...seedProfile(), AppLockRepository.enabledKey: true},
      biometric: FakeBiometricAuth()..kind = null,
    );
    expect(_locked, findsNothing);
    expect(find.text('DOJI SCORE'), findsOneWidget);
  }, variant: ios);

  testWidgets('A8b: passcode fallback asks the system with fallback allowed', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.home,
      seed: {...seedProfile(), AppLockRepository.enabledKey: true},
      biometric: FakeBiometricAuth(results: [BiometricResult.cancelled]),
    );
    await h.tapText('use passcode');
    expect(h.biometric.calls.last.allowFallback, isTrue);
    expect(_locked, findsNothing);
  }, variant: ios);

  testWidgets('A8b: blur in the app switcher; locks again after 5 min away', (tester) async {
    final h = await AppHarness.pump(
      tester,
      at: Routes.home,
      seed: {...seedProfile(), AppLockRepository.enabledKey: true},
    );
    expect(_locked, findsNothing, reason: 'auto unlock succeeded');

    // Briefly away: blurred while away, no lock on return.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await h.wait(50);
    expect(h.container.read(appLockControllerProvider).obscured, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.wait(50);
    expect(h.container.read(appLockControllerProvider).obscured, isFalse);
    expect(_locked, findsNothing);

    // Away for 6 minutes: locked again, and Face ID asked again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(minutes: 6));
    h.biometric.result = BiometricResult.cancelled;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.wait(100);
    expect(_locked, findsOneWidget);
    expect(h.biometric.calls, hasLength(2));
  }, variant: ios);
}
