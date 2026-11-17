import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One 4-7-8 phase: its word and length in seconds.
typedef BreathPhase = ({String word, int seconds});

const kBreathPhases = <BreathPhase>[
  (word: 'breathe in', seconds: 4),
  (word: 'hold', seconds: 7),
  (word: 'breathe out', seconds: 8),
];

/// The phase and seconds left at [second] of the 19s cycle.
({BreathPhase phase, int left}) breathAt(int second) {
  var t = second % 19;
  for (final p in kBreathPhases) {
    if (t < p.seconds) return (phase: p, left: p.seconds - t);
    t -= p.seconds;
  }
  throw StateError('unreachable');
}

/// Design system: `BreathingOrb` (Doji Core Tabs › 11, panic): 4-7-8, 19s
/// cycle. The phase and countdown are text, so it works with motion off:
/// under reduce motion the orb holds a still size per phase.
class BreathingOrb extends StatefulWidget {
  const BreathingOrb({super.key, required this.reduceMotion});

  final bool reduceMotion;

  @override
  State<BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<BreathingOrb> with SingleTickerProviderStateMixin {
  // preserve: reduce motion must not slow the countdown (see Gotchas).
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 19),
    animationBehavior: AnimationBehavior.preserve,
  )..repeat();

  // 0 → 4s grow, hold to 11s, shrink to 19s (the design's b478 keyframes).
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: .55, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 4,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 7),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: .55).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 8,
    ),
  ]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      final at = breathAt((_c.value * 19).floor());
      final i = kBreathPhases.indexOf(at.phase);
      final scale = widget.reduceMotion ? const [0.85, 1.0, 0.7][i] : _scale.transform(_c.value);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            image: true,
            label: 'breathing guide, 4 seconds in, 7 hold, 8 out',
            child: SizedBox.square(
              dimension: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: DojiColors.separator),
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DojiColors.dojiGreen.withValues(alpha: .08),
                        border: Border.all(color: DojiColors.dojiGreen.withValues(alpha: .3)),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: DojiColors.dojiGreen.withValues(alpha: .9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Column(
            children: [
              // Only the phase is announced; the seconds change too often.
              Semantics(
                liveRegion: true,
                child: Text(
                  at.phase.word,
                  style: DojiType.body.copyWith(fontSize: 24, fontWeight: FontWeight.w300),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${at.left}',
                style: DojiType.data.copyWith(fontSize: 28, color: DojiColors.textSecondary),
              ),
            ],
          ),
        ],
      );
    },
  );
}
