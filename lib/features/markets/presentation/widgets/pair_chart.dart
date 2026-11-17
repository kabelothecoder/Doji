import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/candle.dart';
import '../../domain/market_format.dart';
import '../../domain/news.dart';
import '../../domain/pair_brief.dart';

/// Candles are neutral greys: price is never green or orange (handoff 1b,
/// design system › ChartContainer).
const _upCandle = Color(0xFFD9DADD);
const _downCandle = Color(0xFF5C5F66);

/// Overlay tints from the handoff: strategy levels green, news orange.
const _levelLine = Color(0xB32FD67B);
const _levelFill = Color(0x0D2FD67B);
const _newsLine = Color(0xB3FF9F0A);
const _lastLine = Color(0x80F5F5F7);

/// Handoff 1b `ChartContainer(CustomPainter)`: candles in greys, the
/// trader's strategy levels (green dashed band) and the news window (orange
/// dashed line), the last price tagged on the right axis. No signals: only
/// what the trader's own plan draws.
class PairChart extends StatelessWidget {
  const PairChart({
    super.key,
    required this.candles,
    required this.timeframe,
    required this.decimals,
    required this.semanticLabel,
    this.levels,
    this.news,
    this.height = 200,
  });

  final List<Candle> candles;
  final Timeframe timeframe;
  final int decimals;
  final String semanticLabel;
  final StrategyLevels? levels;
  final NewsEvent? news;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            candles: candles,
            timeframe: timeframe,
            decimals: decimals,
            levels: levels,
            news: news,
          ),
        ),
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.candles,
    required this.timeframe,
    required this.decimals,
    required this.levels,
    required this.news,
  });

  final List<Candle> candles;
  final Timeframe timeframe;
  final int decimals;
  final StrategyLevels? levels;
  final NewsEvent? news;

  /// The right-hand tags.
  static const axis = 56.0;

  /// Empty bar slots after the last candle, so an upcoming news window shows.
  static const future = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - axis;
    final h = size.height;
    final grid = Paint()
      ..color = DojiColors.elevated2
      ..strokeWidth = 1;
    for (var y = 0.0; y < h; y += 50) {
      canvas.drawLine(Offset(0, y + 0.5), Offset(plotW, y + 0.5), grid);
    }
    if (candles.isEmpty || plotW <= 0) return;

    // Vertical scale: the candles and the strategy levels, with some air.
    var hi = candles.map((c) => c.high).reduce(math.max);
    var lo = candles.map((c) => c.low).reduce(math.min);
    final range = levels?.range;
    if (range != null) {
      hi = math.max(hi, range.high);
      lo = math.min(lo, range.low);
    }
    final pad = (hi - lo) * 0.08;
    hi += pad;
    lo -= pad;
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    double y(double v) => (hi - v) / (hi - lo) * h;

    final slots = candles.length + future;
    final pitch = plotW / slots;
    double x(int i) => i * pitch + pitch / 2;

    // Strategy levels: a faint band between dashed lines.
    if (range != null) {
      final top = y(range.high), bottom = y(range.low);
      canvas.drawRect(Rect.fromLTRB(0, top, plotW, bottom), Paint()..color = _levelFill);
      final dashed = Paint()
        ..color = _levelLine
        ..strokeWidth = 1;
      _dashH(canvas, top, plotW, dashed, 4, 3);
      _dashH(canvas, bottom, plotW, dashed, 4, 3);
    }

    // The news window: a dashed orange line at the release.
    final event = news;
    if (event != null) {
      final bars = event.at.difference(candles.first.at).inSeconds / timeframe.duration.inSeconds;
      final nx = bars * pitch + pitch / 2;
      if (nx >= 0 && nx <= plotW) {
        _dashV(
          canvas,
          nx,
          h,
          Paint()
            ..color = _newsLine
            ..strokeWidth = 1,
        );
        _text(canvas, 'NEWS', Offset(nx + 5, 4), DojiColors.tiltOrange);
      }
    }

    // Candles: wick, then body.
    final body = math.max(1.5, pitch * 0.66);
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final paint = Paint()..color = c.up ? _upCandle : _downCandle;
      final cx = x(i);
      final wickTop = y(c.high), wickBottom = y(c.low);
      canvas.drawRect(Rect.fromLTWH(cx - 0.5, wickTop, 1, math.max(1, wickBottom - wickTop)), paint);
      final top = y(math.max(c.open, c.close));
      final height = math.max(1.5, (y(c.open) - y(c.close)).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - body / 2, top, body, height), const Radius.circular(1)),
        paint,
      );
    }

    // The last price: a dotted line and a tag.
    final last = candles.last.close;
    final ly = y(last);
    _dashH(
      canvas,
      ly,
      plotW,
      Paint()
        ..color = _lastLine
        ..strokeWidth = 1,
      1,
      2,
    );
    final tags = <(double, String, Color, Color, FontWeight)>[
      if (range != null) ...[
        (y(range.high), levels!.highLabel, DojiColors.grid[1], DojiColors.dojiGreen, FontWeight.w400),
        (y(range.low), levels!.lowLabel, DojiColors.grid[1], DojiColors.dojiGreen, FontWeight.w400),
      ],
    ];
    // Level tags step aside for the price tag rather than cover it.
    final placed = <double>[ly];
    _tag(
      canvas,
      size,
      ly,
      formatPrice(last, decimals),
      DojiColors.textPrimary,
      DojiColors.bg,
      FontWeight.w600,
    );
    for (final (ty, label, bg, fg, weight) in tags) {
      var at = ty;
      for (final p in placed) {
        if ((at - p).abs() < 18) at = at < p ? p - 18 : p + 18;
      }
      at = at.clamp(9, h - 9);
      placed.add(at);
      _tag(canvas, size, at, label, bg, fg, weight);
    }
  }

  void _tag(Canvas canvas, Size size, double cy, String label, Color bg, Color fg, FontWeight weight) {
    final top = (cy - 9).clamp(0.0, size.height - 18);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - axis + 4, top, axis - 4, 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    final tp = _painter(label, fg, weight, maxWidth: axis - 6);
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, top + (18 - tp.height) / 2));
  }

  void _text(Canvas canvas, String text, Offset at, Color color) =>
      _painter(text, color, FontWeight.w400).paint(canvas, at);

  TextPainter _painter(String text, Color color, FontWeight weight, {double maxWidth = 200}) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: DojiFonts.mono,
        fontSize: 10,
        color: color,
        fontWeight: weight,
        height: 1.2,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  void _dashH(Canvas canvas, double y, double width, Paint paint, double dash, double gap) {
    for (var x = 0.0; x < width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, width), y), paint);
    }
  }

  void _dashV(Canvas canvas, double x, double height, Paint paint) {
    for (var y = 0.0; y < height; y += 7) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 4, height)), paint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.candles != candles || old.levels != levels || old.news != news || old.decimals != decimals;
}
