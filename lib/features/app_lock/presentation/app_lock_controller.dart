import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_lock_repository.dart';
import '../data/biometric_auth.dart';
import '../domain/biometric_kind.dart';

@immutable
class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.locked = false,
    this.obscured = false,
    this.authenticating = false,
    this.kind,
    this.kindLoaded = false,
    this.message,
  });

  final bool enabled;

  /// A8b is up; content underneath is blurred and unreachable.
  final bool locked;

  /// Privacy blur while doji is in the background / app switcher.
  final bool obscured;
  final bool authenticating;
  final BiometricKind? kind;
  final bool kindLoaded;

  /// Last failure, shown as a tilt terminal line.
  final String? message;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    bool? obscured,
    bool? authenticating,
    BiometricKind? kind,
    bool? kindLoaded,
    String? Function()? message,
  }) => AppLockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    obscured: obscured ?? this.obscured,
    authenticating: authenticating ?? this.authenticating,
    kind: kind ?? this.kind,
    kindLoaded: kindLoaded ?? this.kindLoaded,
    message: message == null ? this.message : message(),
  );
}

/// Handoff A8: "asks when you open doji, and after 5 min away".
class AppLockController extends Notifier<AppLockState> {
  static const lockAfter = Duration(minutes: 5);
  static const reason = 'unlock doji and keep your journal private';

  DateTime? _hiddenAt;

  AppLockRepository get _repo => ref.read(appLockRepositoryProvider);
  BiometricAuth get _auth => ref.read(biometricAuthProvider);

  @override
  AppLockState build() {
    final enabled = ref.watch(appLockRepositoryProvider).enabled;
    Future.microtask(_loadKind);
    // Cold start counts as "when you open doji".
    return AppLockState(enabled: enabled, locked: enabled);
  }

  Future<void> _loadKind() async {
    final kind = await _auth.availableKind();
    if (!ref.mounted) return;
    state = AppLockState(
      enabled: state.enabled,
      // The device no longer has any lock (biometrics and passcode removed):
      // nothing could unlock doji, so don't trap the user behind it.
      locked: state.locked && kind != null,
      obscured: state.obscured,
      authenticating: state.authenticating,
      kind: kind,
      kindLoaded: true,
      message: state.message,
    );
  }

  /// A8a is offered once, from the second visit to Home on ("after the first
  /// session, never during sign-up"), and only when the device can do it.
  Future<bool> shouldOffer() async {
    await _repo.recordHomeVisit();
    if (_repo.offered || _repo.enabled || _repo.homeVisits < 2) return false;
    if (!state.kindLoaded) await _loadKind();
    if (state.kind == null) return false;
    await _repo.markOffered();
    return true;
  }

  /// Turning it on proves the user can unlock, so nobody locks themselves out.
  Future<bool> enable() async {
    final result = await _authenticate(allowFallback: state.kind == BiometricKind.screenLock);
    if (result != BiometricResult.success) return false;
    await _repo.setEnabled(true);
    await _repo.markOffered();
    state = state.copyWith(enabled: true, message: () => null);
    return true;
  }

  Future<void> disable() async {
    await _repo.setEnabled(false);
    state = state.copyWith(enabled: false, locked: false, message: () => null);
  }

  Future<bool> unlock({bool fallback = false}) async {
    final result = await _authenticate(allowFallback: fallback || state.kind == BiometricKind.screenLock);
    if (result != BiometricResult.success) return false;
    state = state.copyWith(locked: false, obscured: false, message: () => null);
    return true;
  }

  Future<BiometricResult> _authenticate({required bool allowFallback}) async {
    if (state.authenticating) return BiometricResult.cancelled;
    state = state.copyWith(authenticating: true, message: () => null);
    final result = await _auth.authenticate(reason: reason, allowFallback: allowFallback);
    if (!ref.mounted) return result;
    final name = state.kind?.name ?? 'app lock';
    state = state.copyWith(
      authenticating: false,
      message: () => switch (result) {
        BiometricResult.success || BiometricResult.cancelled => null,
        BiometricResult.failed => "couldn't confirm it's you. try again.",
        BiometricResult.lockedOut => '$name is locked for now. use your passcode.',
        BiometricResult.unavailable => '$name isn\'t set up on this device.',
      },
    );
    return result;
  }

  /// The system prompt itself backgrounds the app on iOS and Android; those
  /// transitions are ignored.
  void onBackground() {
    if (state.authenticating) return;
    _hiddenAt ??= clock.now();
    if (state.enabled && !state.obscured) state = state.copyWith(obscured: true);
  }

  void onForeground() {
    if (state.authenticating) return;
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    final away = hiddenAt == null ? Duration.zero : clock.now().difference(hiddenAt);
    state = state.copyWith(obscured: false, locked: state.locked || (state.enabled && away >= lockAfter));
  }

  /// Sign out / delete: forget the lock with the rest of local data.
  Future<void> reset() async {
    await _repo.clear();
    _hiddenAt = null;
    state = AppLockState(kind: state.kind, kindLoaded: state.kindLoaded);
  }
}

final appLockControllerProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
