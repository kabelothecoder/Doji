// DojiMotion — design system section 04 plus the splash keyframes (K1–K5) and
// onboarding timings from design/handoff/Doji Onboarding.dc.html.
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

abstract final class DojiMotion {
  // Design system
  static const standard = SpringCurve(stiffness: 380, damping: 34);
  static const sheet = SpringCurve(stiffness: 260, damping: 30);
  static const gridFill = Duration(milliseconds: 360);
  static const gridStagger = Duration(milliseconds: 4);

  /// cubic-bezier(.2,.9,.3,1.2) — slight overshoot, used for dojiFill.
  static const gridFillCurve = Cubic(0.2, 0.9, 0.3, 1.2);

  /// 1.1s, step, 50% duty.
  static const cursorBlink = Duration(milliseconds: 1100);

  // Onboarding
  /// "Lines type at 28ms/char, 400ms pause between."
  static const typeChar = Duration(milliseconds: 28);
  static const linePause = Duration(milliseconds: 400);

  /// "Single choice auto-advances 350ms after tap."
  static const autoAdvance = Duration(milliseconds: 350);

  /// Pledge: "Press and hold 1.5s."
  static const pledgeHold = Duration(milliseconds: 1500);

  // Splash (ships at 1.5s)
  static const intro = Duration(milliseconds: 1500);

  /// K1–K4 play in the intro; K5 (glide to header) is the route transition.
  static const introBeforeGlide = Duration(milliseconds: 1250);
  static const introGlide = Duration(milliseconds: 250);
  static const k1 = SpringCurve(stiffness: 260, damping: 18);
  static const k2 = Cubic(0.3, 0, 0.2, 1);
  static const k3 = SpringCurve(stiffness: 400, damping: 30);
  static const k5 = SpringCurve(stiffness: 220, damping: 26);

  /// Reduce motion: "S0 icon cross-fades to the K5 header in 200ms linear".
  static const reducedCrossFade = Duration(milliseconds: 200);

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// A damped spring (mass 1) squeezed into the animation's duration.
///
/// The handoff specifies springs as stiffness/damping pairs; Flutter curves are
/// time-normalised, so the physical spring is sampled over its own settle time
/// and mapped onto t ∈ [0, 1]. Overshoot and ringing keep their shape.
class SpringCurve extends Curve {
  const SpringCurve({required this.stiffness, required this.damping, this.mass = 1});

  final double stiffness;
  final double damping;
  final double mass;

  double get _settleTime {
    final omega = math.sqrt(stiffness / mass);
    final zeta = damping / (2 * math.sqrt(stiffness * mass));
    final decay = zeta < 1 ? zeta * omega : omega * (zeta - math.sqrt(zeta * zeta - 1));
    return math.log(1000) / decay; // envelope within 0.1% of rest
  }

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0,
      1,
      0,
    );
    return sim.x(t * _settleTime);
  }
}
