import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/formatting.dart';
import '../../domain/journal_stats.dart';

/// Doji Trade Journal › `EquityCurve`: the running result as a solid white
/// line, with a dashed green "if you'd followed your rules" line (the same
/// trades minus those that broke the plan). An orange bracket at the right
/// edge spans the gap, labelled with what breaking the plan cost.
class EquityCurve extends StatelessWidget {
  const EquityCurve({super.key, required this.stats, required this.currencySymbol});

  final JournalStats stats;
  final String currencySymbol;

  String _fmt(double v) => formatValue(v, stats.unit, currencySymbol);

  String get _costLine {
    if (stats.brokenCount == 0) return 'no trade broke your plan';
    final cost = stats.costOfBreaking;
    if (cost > 1e-9) return 'cost of breaking rules: ${_fmt(-cost)}';
    if (cost < -1e-9) return 'plan-breaking trades paid ${_fmt(-cost)} · luck, not process';
    return 'plan-breaking trades netted ${_fmt(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final hasCurve = s.actual.length >= 3;
    final unitLabel = s.unit == ResultUnit.r ? 'R' : 'MONEY';
    final aria = hasCurve
        ? 'equity curve, ${s.actual.length - 1} trades, ends at ${_fmt(s.actual.last)}. '
              'Followed your rules it would end at ${_fmt(s.ghost.last)}.'
        : 'equity curve, needs at least two trades';
    final broke = s.brokenCount > 0 && s.costOfBreaking > 1e-9;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('EQUITY · $unitLabel', style: DojiType.label.copyWith(fontSize: 11)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Semantics(
              container: true,
              image: true,
              label: aria,
              child: ExcludeSemantics(
                child: hasCurve
                    ? CustomPaint(
                        size: Size.infinite,
                        painter: _CurvePainter(actual: s.actual, ghost: s.ghost, bracket: broke),
                      )
                    : Center(
                        child: Text(
                          'the curve starts with your second trade.',
                          style: DojiType.callout.copyWith(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const ExcludeSemantics(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Legend(color: DojiColors.textPrimary, dashed: false, label: 'actual'),
                _Legend(color: DojiColors.dojiGreen, dashed: true, label: "if you'd followed your rules"),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.separator)),
            ),
            child: Row(
              children: [
                if (broke) ...[
                  Container(
                    width: 10,
                    height: 14,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: DojiColors.tiltOrange, width: 2),
                        right: BorderSide(color: DojiColors.tiltOrange, width: 2),
                        bottom: BorderSide(color: DojiColors.tiltOrange, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _costLine,
                    style: DojiType.data.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: broke ? DojiColors.tiltOrange : DojiColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.dashed, required this.label});

  final Color color;
  final bool dashed;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 16,
        height: 4,
        child: CustomPaint(
          painter: _LegendLine(color: color, dashed: dashed),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: DojiType.hint.copyWith(fontSize: 10)),
    ],
  );
}

class _LegendLine extends CustomPainter {
  _LegendLine({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    _stroke(
      canvas,
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      dashed: dashed,
    );
  }

  @override
  bool shouldRepaint(_LegendLine old) => old.color != color || old.dashed != dashed;
}

void _stroke(Canvas canvas, Path path, Paint paint, {required bool dashed}) {
  if (!dashed) {
    canvas.drawPath(path, paint);
    return;
  }
  for (final m in path.computeMetrics()) {
    for (double d = 0; d < m.length; d += 7) {
      canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
    }
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.actual, required this.ghost, required this.bracket});

  final List<double> actual;
  final List<double> ghost;
  final bool bracket;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...actual, ...ghost, 0.0];
    var lo = all.reduce(math.min), hi = all.reduce(math.max);
    if ((hi - lo).abs() < 1e-9) {
      hi += 1;
      lo -= 1;
    }
    const padY = 8.0, rightPad = 8.0;
    final w = size.width - rightPad, h = size.height - padY * 2;
    double x(int i, int n) => n <= 1 ? 0 : i / (n - 1) * w;
    double y(double v) => padY + (hi - v) / (hi - lo) * h;

    Path line(List<double> v) {
      final p = Path();
      for (var i = 0; i < v.length; i++) {
        final dx = x(i, v.length), dy = y(v[i]);
        i == 0 ? p.moveTo(dx, dy) : p.lineTo(dx, dy);
      }
      return p;
    }

    // Zero line, labelled.
    final zero = Path()
      ..moveTo(0, y(0))
      ..lineTo(size.width, y(0));
    _stroke(
      canvas,
      zero,
      Paint()
        ..color = DojiColors.separator
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
      dashed: true,
    );
    final tp = TextPainter(
      text: TextSpan(text: '0', style: DojiType.hint.copyWith(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(0, y(0) + 2));

    _stroke(
      canvas,
      line(ghost),
      Paint()
        ..color = DojiColors.dojiGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
      dashed: true,
    );
    _stroke(
      canvas,
      line(actual),
      Paint()
        ..color = DojiColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeJoin = StrokeJoin.round,
      dashed: false,
    );

    if (bracket) {
      final bx = w + 4;
      canvas.drawLine(
        Offset(bx, y(ghost.last)),
        Offset(bx, y(actual.last)),
        Paint()
          ..color = DojiColors.tiltOrange
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.actual != actual || old.ghost != ghost || old.bracket != bracket;
}
