import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/platform/platform_info.dart';
import '../domain/biometric_kind.dart';

enum BiometricResult { success, cancelled, failed, lockedOut, unavailable }

/// Face ID / Touch ID on iOS, BiometricPrompt on Android, Windows Hello on
/// Windows. Behind an interface so widget tests never touch the plugin.
abstract interface class BiometricAuth {
  /// Null when the device has nothing to unlock with ("unavailable: hide setup").
  Future<BiometricKind?> availableKind();

  /// [allowFallback] lets the system offer the passcode / PIN.
  Future<BiometricResult> authenticate({required String reason, bool allowFallback = false});
}

class LocalAuthBiometricAuth implements BiometricAuth {
  LocalAuthBiometricAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricKind?> availableKind() async {
    try {
      if (!await _auth.isDeviceSupported()) return null;
      if (PlatformInfo.isWindows) return BiometricKind.windowsHello;
      final types = await _auth.getAvailableBiometrics();
      if (PlatformInfo.isIOS) {
        if (types.contains(BiometricType.face)) return BiometricKind.faceId;
        if (types.contains(BiometricType.fingerprint)) return BiometricKind.touchId;
        return BiometricKind.screenLock;
      }
      if (types.contains(BiometricType.fingerprint)) return BiometricKind.fingerprint;
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.strong) || types.contains(BiometricType.weak)) {
        return BiometricKind.biometrics;
      }
      return BiometricKind.screenLock;
    } on Object catch (e) {
      debugPrint('app lock unavailable: $e');
      return null;
    }
  }

  @override
  Future<BiometricResult> authenticate({required String reason, bool allowFallback = false}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Windows Hello can't be limited to biometrics.
        biometricOnly: !allowFallback && !PlatformInfo.isWindows,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback => BiometricResult.cancelled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => BiometricResult.lockedOut,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet => BiometricResult.unavailable,
        _ => BiometricResult.failed,
      };
    } on PlatformException {
      return BiometricResult.failed;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>((ref) => LocalAuthBiometricAuth());
