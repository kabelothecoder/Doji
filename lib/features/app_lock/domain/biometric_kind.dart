import 'package:flutter/material.dart';

/// What unlocks doji on this device. The handoff is written for Face ID; each
/// platform gets its own honest name in the same layout.
enum BiometricKind {
  faceId,
  touchId,
  fingerprint,
  face,

  /// Android "strong" biometrics without a specific type.
  biometrics,
  windowsHello,

  /// No biometrics enrolled, but a passcode / PIN / pattern is.
  screenLock;

  /// "turn on Face ID", "unlock with Windows Hello", settings value.
  String get name => switch (this) {
    faceId => 'Face ID',
    touchId => 'Touch ID',
    fingerprint => 'fingerprint',
    face => 'face unlock',
    biometrics => 'biometrics',
    windowsHello => 'Windows Hello',
    screenLock => 'screen lock',
  };

  /// "lock doji with …"
  String get phrase => switch (this) {
    fingerprint => 'your fingerprint',
    screenLock => 'your screen lock',
    _ => name,
  };

  IconData get icon => switch (this) {
    faceId || face || windowsHello => Icons.face_unlock_outlined,
    touchId || fingerprint || biometrics => Icons.fingerprint_rounded,
    screenLock => Icons.lock_outline_rounded,
  };
}
