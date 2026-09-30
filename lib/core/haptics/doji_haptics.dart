import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_info.dart';

/// Haptic ticks named after where the handoff uses them.
/// No-op on Windows (and anywhere without a haptic engine).
class DojiHaptics {
  const DojiHaptics();

  bool get _enabled => PlatformInfo.hasHaptics;

  /// Selection tick: each typed wordmark char, chip selection.
  Future<void> tick() async {
    if (_enabled) await HapticFeedback.selectionClick();
  }

  /// Light impact: doji settles (K3), pledge every 25%, reduce-motion intro.
  Future<void> light() async {
    if (_enabled) await HapticFeedback.lightImpact();
  }

  /// Heavy thud: pledge complete.
  Future<void> heavy() async {
    if (_enabled) await HapticFeedback.heavyImpact();
  }
}

final hapticsProvider = Provider<DojiHaptics>((ref) => const DojiHaptics());
