import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../markets/domain/candle.dart';
import '../../../markets/domain/market_format.dart';
import '../../domain/chart_viewport.dart';
import '../../domain/drawing.dart';
import '../../domain/hit_test.dart';

/// Candles are neutral greys: price is never green or orange (same as 1b's
/// `PairChart`, design system › ChartContainer).
const _upCandle = Color(0xFFD9DADD);
const _downCandle = Color(0xFF5C5F66);
const _lastLine = Color(0x80F5F5F7);

/// The trader's own marks: grey, white when selected. Only the position's
/// stop and target zones carry orange / green, and each says so in words.
const _mark = DojiColors.textSecondary;
const _markSelected = DojiColors.textPrimary;

/// Paints doji's chart: candles on the viewport, the trader's drawings, the
/// selection handles, a draft being drawn and the crosshair.
class ChartPainter extends CustomPainter {
  ChartPainter({
    required this.geometry,
    required this.decimals,
    required this.drawings,
    required this.selectedId,
    required this.positionLabel,
    required this.timeLabel,
    this.draft,
    this.crosshair,
  });

  final ChartGeometry geometry;
  final int decimals;
  final List<Drawing> drawings;
  final String? selectedId;

  /// The figures line over a position box ("1 : 2.0 R · risk R 500 (1%) · 0.42 lots").
  final String Function(Drawing d) positionLabel;
  final String Function(DateTime t) timeLabel;
  final Drawing? draft;
  final Offset? crosshair;

  static const axis = 56.0;

  List<Candle> get bars => geometry.bars;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final plotW = g.plot.width;
    final h = g.plot.height;
    final grid = Paint()
      ..color = DojiColors.elevated2
      ..strokeWidth = 1;
    for (var y = 0.0; y < h; y += 50) {
      canvas.drawLine(Offset(0, y + 0.5), Offset(plotW, y + 0.5), grid);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plotW, h));

    final first = math.max(0, g.viewport.start.floor() - 1);
    final last = math.min(bars.length, (g.viewport.start + g.viewport.count).ceil() + 1);
    final body = math.max(1.5, g.pitch * 0.66);
    for (var i = first; i < last; i++) {
      final c = bars[i];
      final paint = Paint()..color = c.up ? _upCandle : _downCandle;
      final cx = g.xOfIndex(i.toDouble());
      final wickTop = g.yOf(c.high), wickBottom = g.yOf(c.low);
      canvas.drawRect(Rect.fromLTWH(cx - 0.5, wickTop, 1, math.max(1, wickBottom - wickTop)), paint);
      final top = g.yOf(math.max(c.open, c.close));
      final height = math.max(1.5, (g.yOf(c.open) - g.yOf(c.close)).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - body / 2, top, body, height), const Radius.circular(1)),
        paint,
      );
    }

    for (final d in [...drawings, ?draft]) {
      _drawing(canvas, d, selected: d.id == selectedId || identical(d, draft));
    }
    final sel = drawings.where((d) => d.id == selectedId).firstOrNull;
    if (sel != null) {
      for (final p in handlesOf(sel, g).values) {
        canvas.drawCircle(p, 6, Paint()..color = DojiColors.bg);
        canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = _markSelected
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    canvas.restore();

    // Axis tags: the last price, then each level, then the crosshair.
    if (bars.isNotEmpty) {
      final ly = g.yOf(bars.last.close);
      _dashH(canvas, ly, plotW, Paint()..color = _lastLine, 1, 2);
      _tag(canvas, size, ly, formatPrice(bars.last.close, decimals), DojiColors.textPrimary, DojiColors.bg);
    }
    for (final d in drawings.where((d) => d.kind == DrawingKind.level)) {
      _tag(canvas, size, g.yOf(d.a.price), formatPrice(d.a.price, decimals), DojiColors.elevated2, _mark);
    }
    final ch = crosshair;
    if (ch != null && ch.dx >= 0 && ch.dx <= plotW && ch.dy >= 0 && ch.dy <= h) {
      final p = Paint()..color = DojiColors.textTertiary;
      _dashH(canvas, ch.dy, plotW, p, 3, 3);
      for (var y = 0.0; y < h; y += 6) {
        canvas.drawLine(Offset(ch.dx, y), Offset(ch.dx, math.min(y + 3, h)), p);
      }
      _tag(
        canvas,
        size,
        ch.dy,
        formatPrice(g.priceOf(ch.dy), decimals),
        DojiColors.elevated2,
        DojiColors.textPrimary,
      );
      final tp = _painter(
        timeLabel(g.timeOfIndex(g.indexOfX(ch.dx))),
        DojiColors.textPrimary,
        FontWeight.w400,
      );
      final left = (ch.dx - tp.width / 2 - 4).clamp(0.0, plotW - tp.width - 8);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, h - tp.height - 6, tp.width + 8, tp.height + 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = DojiColors.elevated2);
      tp.paint(canvas, Offset(left + 4, h - tp.height - 4));
    }
  }

  void _drawing(Canvas canvas, Drawing d, {required bool selected}) {
    final g = geometry;
    final color = selected ? _markSelected : _mark;
    final line = Paint()
      ..color = color
      ..strokeWidth = selected ? 1.5 : 1
      ..style = PaintingStyle.stroke;
    final a = g.offsetOf(d.a);
    switch (d.kind) {
      case DrawingKind.level:
        canvas.drawLine(Offset(0, a.dy), Offset(g.plot.width, a.dy), line);
      case DrawingKind.trendLine:
        canvas.drawLine(a, g.offsetOf(d.b!), line);
      case DrawingKind.zone:
        final r = Rect.fromPoints(a, g.offsetOf(d.b!));
        canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.10));
        canvas.drawRect(r, line);
      case DrawingKind.position:
        final x2 = g.xOf(d.b!.at);
        final left = math.min(a.dx, x2), right = math.max(a.dx, x2);
        final ty = g.yOf(d.target!), sy = g.yOf(d.stop!);
        final target = Rect.fromLTRB(left, math.min(a.dy, ty), right, math.max(a.dy, ty));
        final stop = Rect.fromLTRB(left, math.min(a.dy, sy), right, math.max(a.dy, sy));
        _zone(
          canvas,
          target,
          DojiColors.dojiGreen,
          'target ${formatPrice(d.target!, decimals)}',
          top: ty < a.dy,
        );
        _zone(canvas, stop, DojiColors.tiltOrange, 'stop ${formatPrice(d.stop!, decimals)}', top: sy < a.dy);
        canvas.drawLine(Offset(left, a.dy), Offset(right, a.dy), line..strokeWidth = selected ? 2 : 1.5);
        final label = _painter(positionLabel(d), color, FontWeight.w600, maxWidth: g.plot.width - 8);
        final above = math.min(target.top, stop.top) - label.height - 4;
        final lx = math.max(4.0, math.min(left, g.plot.width - label.width - 4));
        label.paint(canvas, Offset(lx, above < 0 ? math.max(target.bottom, stop.bottom) + 4 : above));
    }
  }

  /// A position's target or stop zone: tinted, outlined and named in words.
  void _zone(Canvas canvas, Rect r, Color c, String label, {required bool top}) {
    canvas.drawRect(r, Paint()..color = c.withValues(alpha: 0.10));
    canvas.drawRect(
      r,
      Paint()
        ..color = c.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke,
    );
    final tp = _painter(label, c, FontWeight.w600);
    final x = math.max(4.0, math.min(r.left + 4, geometry.plot.width - tp.width - 4));
    tp.paint(canvas, Offset(x, top ? r.top + 3 : r.bottom - tp.height - 3));
  }

  void _tag(Canvas canvas, Size size, double cy, String label, Color bg, Color fg) {
    final top = (cy - 9).clamp(0.0, math.max(0.0, size.height - 18)).toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - axis + 4, top, axis - 4, 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    final tp = _painter(label, fg, FontWeight.w600, maxWidth: axis - 6);
    tp.paint(canvas, Offset(rect.left + (rect.width - tp.width) / 2, top + (18 - tp.height) / 2));
  }

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

  @override
  bool shouldRepaint(ChartPainter old) =>
      old.geometry.viewport != geometry.viewport ||
      old.geometry.bars != geometry.bars ||
      old.geometry.plot != geometry.plot ||
      old.drawings != drawings ||
      old.selectedId != selectedId ||
      old.draft != draft ||
      old.crosshair != crosshair ||
      old.decimals != decimals;
}
