import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../a11y/semantics_ext.dart';
import '../haptics/doji_haptics.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'glass_surface.dart';

/// Design system: `HoldToConfirm` in the handoff's Flutter map
/// (`HoldToPledgeButton` in the brief).
///
/// "Press and hold 1.5s. Ring fills linearly; light haptic every 25%, heavy
/// thud at 100%. Releasing early rewinds with a spring."
///
/// Also: hold Space or Enter for 1.5s (keyboard), and screen-reader users can
/// trigger it with the long-press action (double-tap and hold).
class HoldToPledgeButton extends ConsumerStatefulWidget {
  const HoldToPledgeButton({
    super.key,
    required this.onPledged,
    this.duration = DojiMotion.pledgeHold,
    this.semanticLabel = "hold to pledge: i'll trade my plan, not my feelings.",
    this.pledged = false,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback onPledged;
  final Duration duration;
  final String semanticLabel;

  /// Already pledged (e.g. resumed): ring full, input disabled.
  final bool pledged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  ConsumerState<HoldToPledgeButton> createState() => _HoldToPledgeButtonState();
}

class _HoldToPledgeButtonState extends ConsumerState<HoldToPledgeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.pledged ? 1 : 0,
  )..addListener(_onProgress);

  int _quarter = 0;
  bool _holding = false;
  bool _done = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _done = widget.pledged;
  }

  void _onProgress() {
    if (!_holding || _done) return;
    final q = (_hold.value * 4).floor();
    if (q > _quarter && q < 4) {
      _quarter = q;
      ref.read(hapticsProvider).light();
    }
    if (_hold.value >= 1) _complete();
  }

  void _start() {
    if (_done || _holding) return;
    _holding = true;
    _quarter = (_hold.value * 4).floor();
    // Resume from wherever a spring-back left the ring, at the same fill rate.
    _hold.animateTo(1, duration: widget.duration * (1 - _hold.value), curve: Curves.linear);
    setState(() {});
  }

  void _release() {
    if (!_holding || _done) return;
    _holding = false;
    if (DojiMotion.reduced(context)) {
      _hold.value = 0;
    } else {
      _hold.animateBack(0, duration: const Duration(milliseconds: 420), curve: DojiMotion.standard);
    }
    setState(() {});
  }

  void _complete() {
    if (_done) return;
    _done = true;
    _holding = false;
    _hold.value = 1;
    ref.read(hapticsProvider).heavy();
    announce(context, 'pledged');
    setState(() {});
    widget.onPledged();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isHoldKey =
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isHoldKey) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _start();
    } else if (event is KeyUpEvent) {
      _release();
    }
    // Swallow repeats too, so holding Enter doesn't also trigger "continue".
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _done ? 'pledged' : 'hold';
    return Semantics(
      container: true,
      button: true,
      enabled: !_done,
      label: widget.semanticLabel,
      value: _done ? 'pledged' : null,
      hint: _done ? null : 'double tap and hold for 1.5 seconds',
      onLongPress: _done ? null : _complete,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _onKey,
          onFocusChange: (f) => setState(() => _focused = f),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Listener(
                onPointerDown: (_) => _start(),
                onPointerUp: (_) => _release(),
                onPointerCancel: (_) => _release(),
                child: MouseRegion(
                  cursor: _done ? SystemMouseCursors.basic : SystemMouseCursors.click,
                  child: SizedBox.square(
                    dimension: 128,
                    child: AnimatedBuilder(
                      animation: _hold,
                      builder: (context, _) => CustomPaint(
                        painter: _RingPainter(progress: _hold.value, focused: _focused),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: AnimatedScale(
                            scale: _holding && !DojiMotion.reduced(context) ? 0.97 : 1,
                            duration: const Duration(milliseconds: 120),
                            child: GlassSurface(
                              circle: true,
                              tint: DojiColors.elevated2,
                              blur: 26,
                              child: Center(
                                child: Text(
                                  label,
                                  style: DojiType.hint.copyWith(
                                    fontSize: 13,
                                    color: _done ? DojiColors.dojiGreen : DojiColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _hold,
                builder: (context, _) => Text(
                  _done
                      ? 'PLEDGED · RULES V1'
                      : 'HOLD ${(widget.duration.inMilliseconds / 1000).toStringAsFixed(1)}S TO PLEDGE'
                            '${_hold.value > 0 ? ' · ${(_hold.value * 100).round()}%' : ''}',
                  style: DojiType.hint.copyWith(
                    color: _done ? DojiColors.dojiGreen : DojiColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.focused});

  final double progress;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 61.0;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = DojiColors.separator;
    canvas.drawCircle(c, r, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = DojiColors.dojiGreen,
      );
    }
    if (focused) {
      canvas.drawCircle(
        c,
        r + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = DojiColors.dojiGreen.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.focused != focused;
}
