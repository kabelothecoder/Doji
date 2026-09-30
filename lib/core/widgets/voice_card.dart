import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_button.dart';
import 'doji_choice_chip.dart';
import 'doji_pressable.dart';

/// Design system: `VoiceCard(onPlay)` + `Waveform(CustomPainter)` from the
/// onboarding handoff (step 5a).
///
/// Tapping the card selects the voice; the round button previews it. Previews
/// are placeholders until real voice lines exist (handoff open item), so play
/// only animates the waveform.
class VoiceCard extends StatefulWidget {
  const VoiceCard({
    super.key,
    required this.name,
    required this.seed,
    required this.selected,
    required this.playing,
    required this.onSelect,
    required this.onPlay,
    this.placeholder = true,
  });

  final String name;

  /// Seeds the static waveform shape so each voice looks different.
  final int seed;
  final bool selected;
  final bool playing;
  final VoidCallback onSelect;
  final VoidCallback onPlay;
  final bool placeholder;

  @override
  State<VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<VoiceCard> with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceCard old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.playing && !DojiMotion.reduced(context)) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DojiChoiceChip.radiusFor(Theme.of(context).platform));
    final tag = [
      if (widget.playing) 'PLAYING',
      if (widget.selected) 'SELECTED',
      if (widget.placeholder) 'PLACEHOLDER PREVIEW',
    ].join(' · ');
    return DojiPressable(
      onPressed: widget.onSelect,
      borderRadius: radius,
      checked: widget.selected,
      inMutuallyExclusiveGroup: true,
      activateOnEnter: false,
      semanticLabel: '${widget.name} voice',
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: DojiColors.elevated1,
          borderRadius: radius,
          border: Border.all(color: widget.selected ? DojiColors.dojiGreen : DojiColors.separator),
        ),
        child: Row(
          children: [
            DojiIconButton(
              icon: widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              semanticLabel: '${widget.playing ? 'Pause' : 'Play'} ${widget.name} preview',
              onPressed: widget.onPlay,
              filled: widget.playing,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.name, style: DojiType.choice),
                  const SizedBox(height: 4),
                  Text(tag, style: DojiType.hint.copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: SizedBox(
                width: 92,
                height: 28,
                child: AnimatedBuilder(
                  animation: _wave,
                  builder: (context, _) => CustomPaint(
                    painter: WaveformPainter(seed: widget.seed, playing: widget.playing, phase: _wave.value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 18 bars, 3px wide, 2px gap. Heights come from the handoff's LCG
/// (s = s·16807 mod 2³¹−1, h = .3 + (s mod 70)/100). While playing, the first
/// 11 bars are green and every bar breathes on its own period.
class WaveformPainter extends CustomPainter {
  WaveformPainter({required this.seed, required this.playing, required this.phase});

  final int seed;
  final bool playing;
  final double phase;

  static List<double> heights(int seed) {
    final hs = <double>[];
    var s = seed;
    for (var i = 0; i < 18; i++) {
      s = (s * 16807) % 2147483647;
      hs.add(0.3 + (s % 70) / 100);
    }
    return hs;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hs = heights(seed);
    final paint = Paint();
    for (var i = 0; i < hs.length; i++) {
      var h = hs[i] * size.height;
      if (playing) {
        final period = 0.7 + (i % 5) * 0.12;
        final t = ((phase * 1.2 / period) + i * 0.04) % 1;
        final wave = 0.35 + 0.65 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
        h *= wave;
      }
      paint.color = playing && i < 11 ? DojiColors.dojiGreen : DojiColors.separator;
      final x = i * 5.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x + 1.5, size.height / 2), width: 3, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) => old.seed != seed || old.playing != playing || old.phase != phase;
}
