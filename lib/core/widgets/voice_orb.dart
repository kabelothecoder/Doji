import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

enum VoiceOrbState { idle, listening, speaking }

/// Design system: `VoiceOrb(state)` (Doji Hero Screens 1c, `VoiceOrb` card).
///
/// A textured green orb. Idle: still, 70% opacity, a quiet glow. Listening:
/// breathes on a 4s loop (scale 1 → 1.045). Speaking: three rings ripple out
/// (2.4s, 0.8s apart). Reduce motion swaps both for an opacity change.
///
/// [size] is the box the orb sits in; the orb is 75% of it and the rings
/// ripple past its edge.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key, required this.state, this.size = 200});

  final VoiceOrbState state;
  final double size;

  static const _breathe = Duration(seconds: 4);
  static const _ripple = Duration(milliseconds: 2400);

  /// cubic-bezier(.2,.6,.3,1)
  static const _rippleCurve = Cubic(0.2, 0.6, 0.3, 1);

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = DojiMotion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(VoiceOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync();
  }

  void _sync() {
    final duration = switch (widget.state) {
      VoiceOrbState.listening => VoiceOrb._breathe,
      VoiceOrbState.speaking => VoiceOrb._ripple,
      VoiceOrbState.idle => null,
    };
    if (duration == null || _reduced) {
      _loop.stop();
      _loop.value = 0;
      return;
    }
    if (_loop.duration != duration || !_loop.isAnimating) {
      _loop
        ..duration = duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final orb = widget.size * 0.75;
    final idle = state == VoiceOrbState.idle;
    return Semantics(
      image: true,
      label: 'voice orb, ${state.name}',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, child) {
            final t = _loop.value;
            final breathing = state == VoiceOrbState.listening && !_reduced;
            // 0 → 1 → 0 over the loop, eased at both ends.
            final breath = Curves.easeInOut.transform(1 - (2 * t - 1).abs());
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (state == VoiceOrbState.speaking && !_reduced)
                  for (var i = 0; i < 3; i++) _ring(orb, (t + i / 3) % 1),
                Transform.scale(scale: breathing ? 1 + 0.045 * breath : 1, child: child),
              ],
            );
          },
          child: AnimatedOpacity(
            opacity: idle ? 0.7 : 1,
            duration: DojiMotion.reducedCrossFade,
            child: _OrbBody(diameter: orb, glowing: !idle),
          ),
        ),
      ),
    );
  }

  /// One ripple at loop phase [phase]: scale .8 → 1.55 while it fades out.
  Widget _ring(double orb, double phase) {
    final p = VoiceOrb._rippleCurve.transform(phase);
    return IgnorePointer(
      child: Transform.scale(
        scale: 0.8 + 0.75 * p,
        child: Container(
          width: orb,
          height: orb,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: DojiColors.dojiGreen.withValues(alpha: 0.55 * 0.55 * (1 - p))),
          ),
        ),
      ),
    );
  }
}

class _OrbBody extends StatelessWidget {
  const _OrbBody({required this.diameter, required this.glowing});

  final double diameter;
  final bool glowing;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      // radial-gradient(circle at 36% 30%, …) sized to the farthest corner.
      gradient: const RadialGradient(
        center: Alignment(-0.28, -0.4),
        radius: 0.95,
        colors: [
          Color(0xFF5BF0A0),
          DojiColors.dojiGreen,
          Color(0xFF1E6B3E),
          Color(0xFF0B2415),
          DojiColors.bg,
        ],
        stops: [0, 0.16, 0.46, 0.76, 1],
      ),
      boxShadow: [
        BoxShadow(
          color: DojiColors.dojiGreen.withValues(alpha: glowing ? 0.28 : 0.12),
          blurRadius: diameter * (glowing ? 0.43 : 0.19),
        ),
      ],
    ),
    child: CustomPaint(painter: _TexturePainter(shade: glowing)),
  );
}

/// The dot screen over the orb, plus the lower inner shadow when it is lit.
class _TexturePainter extends CustomPainter {
  const _TexturePainter({required this.shade});

  final bool shade;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centre = size.center(Offset.zero);
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
    if (shade) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x00000000), Color(0x80000000)],
            stops: [0, 0.62, 1],
          ).createShader(Offset.zero & size),
      );
    }
    // 30 dots across, each about a fifth of the pitch wide.
    final pitch = size.shortestSide / 30;
    final dot = Paint()..color = const Color(0x8C000000);
    final dotRadius = math.max(0.6, pitch * 0.2);
    for (var y = pitch / 2; y < size.height; y += pitch) {
      for (var x = pitch / 2; x < size.width; x += pitch) {
        canvas.drawCircle(Offset(x, y), dotRadius, dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TexturePainter old) => old.shade != shade;
}
