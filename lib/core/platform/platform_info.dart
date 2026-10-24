import 'package:flutter/foundation.dart';

/// One place to ask "what are we running on" so widgets stay testable:
/// tests override [debugDefaultTargetPlatformOverride] and everything follows.
abstract final class PlatformInfo {
  static TargetPlatform get platform => defaultTargetPlatform;

  static bool get isWindows => !kIsWeb && platform == TargetPlatform.windows;
  static bool get isAndroid => !kIsWeb && platform == TargetPlatform.android;
  static bool get isIOS => !kIsWeb && platform == TargetPlatform.iOS;

  /// Pointer-first platforms get the handoff's desktop density (32px rows).
  static bool get isDesktop =>
      !kIsWeb &&
      (platform == TargetPlatform.windows ||
          platform == TargetPlatform.macOS ||
          platform == TargetPlatform.linux);

  /// "load your profile.doji on this phone" — copy stays true on Windows.
  static String get deviceNoun => isDesktop ? 'computer' : 'phone';

  /// Haptics exist only on phones.
  static bool get hasHaptics => isIOS || isAndroid;
}
