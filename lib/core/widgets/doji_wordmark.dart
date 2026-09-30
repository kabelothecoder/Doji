import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Design system: `DojiWordmark` (Brand).
///
/// "Geist Mono Bold, always lowercase." The i is a doji candle (open = close)
/// and the underscore is the terminal cursor in doji-green. Logos don't scale
/// with text size, so this ignores the text scaler.
///
/// The intro drives [typedChars], [cursorVisible] and [showCandle] to type the
/// word in around a candle that has just settled into a doji.
class DojiWordmark extends StatelessWidget {
  const DojiWordmark({
    super.key,
    this.size = 18,
    this.color = DojiColors.textPrimary,
    this.cursorColor = DojiColors.dojiGreen,
    this.typedChars = 3,
    this.cursorVisible = true,
    this.showCandle = true,
    this.candleKey,
  });

  final double size;
  final Color color;
  final Color cursorColor;

  /// How many of "d", "o", "j" are visible (0–3). Hidden letters keep their
  /// width so the i never moves while the word types in.
  final int typedChars;
  final bool cursorVisible;
  final bool showCandle;

  /// Lets the intro find where the candle-i sits so the big candle can land on it.
  final GlobalKey? candleKey;

  static const String semanticLabel = 'doji';

  @override
  Widget build(BuildContext context) {
    const hidden = TextStyle(color: Colors.transparent);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: DojiType.wordmark.copyWith(fontSize: size, color: color),
            children: [
              for (var i = 0; i < 3; i++) TextSpan(text: 'doj'[i], style: i < typedChars ? null : hidden),
              WidgetSpan(
                alignment: PlaceholderAlignment.aboveBaseline,
                baseline: TextBaseline.alphabetic,
                child: SizedBox(
                  key: candleKey,
                  width: 0.6 * size,
                  height: 0.74 * size,
                  child: showCandle ? CustomPaint(painter: CandleIPainter(color: color)) : null,
                ),
              ),
              TextSpan(
                text: '_',
                style: TextStyle(color: cursorVisible ? cursorColor : Colors.transparent),
              ),
            ],
          ),
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// The doji "i": a full-height wick (0.12em) and a flat body (0.11em) whose
/// top edge sits at 50%, exactly as the handoff's CSS draws it.
class CandleIPainter extends CustomPainter {
  const CandleIPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final em = size.height / 0.74;
    final r = Radius.circular(math.max(1, em / 36));
    final paint = Paint()..color = color;
    final wickW = 0.12 * em;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width / 2 - wickW / 2, 0, wickW, size.height), r),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.1 * em, size.height / 2, size.width - 0.1 * em, size.height / 2 + 0.11 * em),
        r,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CandleIPainter old) => old.color != color;
}

/// The splash wordmark "glides up and becomes the onboarding header"
/// (handoff K5: spring(220, 26) · shared-element Hero). Every screen with the
/// wordmark in its header wraps it in this.
class WordmarkHero extends StatelessWidget {
  const WordmarkHero({super.key, required this.child});

  static const tag = 'doji-wordmark';

  final DojiWordmark child;

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    createRectTween: (begin, end) => _SpringRectTween(begin: begin, end: end),
    // Scale one big wordmark into the flying rect so the glyphs shrink
    // smoothly instead of re-laying out at every frame.
    // The shuttle flies in the Overlay, outside any Material, so give it a
    // text context or Flutter paints its yellow "missing Material" underline.
    flightShuttleBuilder: (context, animation, direction, from, to) => Material(
      type: MaterialType.transparency,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        child: DojiWordmark(size: 72, color: child.color, cursorColor: child.cursorColor),
      ),
    ),
    child: child,
  );
}

class _SpringRectTween extends RectTween {
  _SpringRectTween({super.begin, super.end});

  static const _curve = DojiMotion.k5;

  @override
  Rect? lerp(double t) => super.lerp(_curve.transform(t));
}
