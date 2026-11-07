import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Design spec `MiniGrid`: 12 weeks × 7 days on the five-step green scale,
/// future days outlined, today ringed while the day is open. [days] is
/// column-major (Mon first). The fill animation plays when today's cell
/// changes state, once. Days in [practice] (gym drill days) carry a small
/// dot: practice, kept apart from the trading-day fill.
class MiniGrid extends StatelessWidget {
  const MiniGrid({
    super.key,
    required this.days,
    required this.label,
    this.todayIndex,
    this.weeks = 12,
    this.practice = const {},
  });

  final Set<int> practice;

  final List<GridCellState> days;
  final String label;
  final int? todayIndex;
  final int weeks;

  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) {
            final cell = ((c.maxWidth - _gap * (weeks - 1)) / weeks).floorToDouble();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var w = 0; w < weeks; w++)
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++) ...[
                        if (d > 0) const SizedBox(height: _gap),
                        _cell(cell, w * 7 + d),
                      ],
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

extension on MiniGrid {
  Widget _cell(double size, int i) {
    final c = GridCell(size: size, state: days[i], animateIn: i == todayIndex);
    if (!practice.contains(i)) return c;
    return Stack(
      alignment: Alignment.center,
      children: [
        c,
        Container(
          width: (size / 3).clamp(3, 6).toDouble(),
          height: (size / 3).clamp(3, 6).toDouble(),
          decoration: const BoxDecoration(color: DojiColors.textPrimary, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

/// "less ▪▪▪▪▪ more": the legend under the full grid.
class GridLegend extends StatelessWidget {
  const GridLegend({super.key, this.weeks = 12});

  final int weeks;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text('$weeks weeks', style: DojiType.hint.copyWith(fontSize: 11)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('less', style: DojiType.hint.copyWith(fontSize: 11)),
            const SizedBox(width: 6),
            for (final c in DojiColors.grid) ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 4),
            ],
            Text('more', style: DojiType.hint.copyWith(fontSize: 11)),
          ],
        ),
      ],
    ),
  );
}
