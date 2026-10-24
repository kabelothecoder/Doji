import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';
import '../../domain/formatting.dart';
import '../../domain/journal_stats.dart';
import 'dashed_border.dart';

/// Doji Trade Journal › `ResultHeatmap`: this month as a grid, Monday first.
/// An up day is a green fill with "+", a down day an orange ring with "−",
/// a flat day "0", a day without trades is faint. Tap a day to read it.
/// Private: it never appears on the public doji grid.
class ResultHeatmap extends StatelessWidget {
  const ResultHeatmap({
    super.key,
    required this.month,
    required this.today,
    required this.days,
    required this.unit,
    required this.currencySymbol,
    required this.selected,
    required this.onSelect,
  });

  /// Any day in the month to draw.
  final DateTime month;

  /// Days after this are "upcoming".
  final DateTime today;
  final Map<int, DayResult> days;
  final ResultUnit unit;
  final String currencySymbol;
  final int? selected;
  final ValueChanged<int> onSelect;

  static const _inset = EdgeInsets.symmetric(horizontal: 14);
  static const _gridInset = EdgeInsets.symmetric(horizontal: 3);
  static const _letters = ['m', 't', 'w', 't', 'f', 's', 's'];

  String _describe(int day) {
    final r = days[day];
    final date = '$day ${monthShort(month.month)}';
    if (r == null) return '$date · no trades';
    final value = unit == ResultUnit.r && r.net == 0 && r.trades > 0
        ? '0R'
        : formatValue(r.net, unit, currencySymbol);
    return '$date · $value · ${r.trades} ${r.trades == 1 ? 'trade' : 'trades'}';
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = lead + count;
    final rows = (cells / 7).ceil();
    final isCurrent = month.year == today.year && month.month == today.month;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: DojiColors.elevated1,
        borderRadius: BorderRadius.circular(DojiRadius.card),
        border: Border.all(color: DojiColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: _inset,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'CALENDAR · ${monthShort(month.month).toUpperCase()}',
                      style: DojiType.label.copyWith(fontSize: 11),
                    ),
                  ),
                ),
                const Icon(Icons.lock_outline_rounded, size: 14, color: DojiColors.textSecondary),
                const SizedBox(width: 4),
                Text('private', style: DojiType.hint.copyWith(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // The grid runs nearly edge to edge so every day is a 44pt target; the
          // drawn square is inset inside it.
          Padding(
            padding: _gridInset,
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (final l in _letters)
                        Expanded(
                          child: Center(child: Text(l, style: DojiType.hint.copyWith(fontSize: 10))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                for (var row = 0; row < rows; row++)
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(child: _cell(row * 7 + col - lead + 1, count, isCurrent)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: _inset,
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Text(
                selected == null ? 'tap a day to see its result' : _describe(selected!),
                style: DojiType.hint.copyWith(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: _inset,
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _Key(glyph: '+', color: DojiColors.dojiGreen, fill: true, label: 'up day'),
                  _Key(glyph: '−', color: DojiColors.tiltOrange, fill: false, label: 'down day'),
                  _Key(glyph: '', color: DojiColors.separator, fill: false, label: 'no trades'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: _inset,
            child: Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: DojiColors.separator)),
              ),
              child: Text(
                'only you see this. your public doji grid shows discipline, never results.',
                style: DojiType.hint.copyWith(fontSize: 11, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int day, int count, bool isCurrent) {
    if (day < 1 || day > count) return const SizedBox(height: 44);
    final future = isCurrent && day > today.day;
    final r = days[day];
    final isSel = selected == day;

    Color border = DojiColors.divider, fill = DojiColors.bg, fg = DojiColors.textSecondary;
    String glyph = '';
    if (r != null && r.trades > 0) {
      if (r.up) {
        border = DojiColors.dojiGreen;
        fill = DojiColors.greenTint;
        fg = DojiColors.dojiGreen;
        glyph = '+';
      } else if (r.down) {
        border = DojiColors.tiltOrange;
        fill = Colors.transparent;
        fg = DojiColors.tiltOrange;
        glyph = '−';
      } else {
        border = DojiColors.separator;
        fill = Colors.transparent;
        glyph = '0';
      }
    }

    final body = SizedBox(
      height: 40,
      child: Stack(
        children: [
          Positioned(left: 5, top: 3, child: Text('$day', style: DojiType.hint.copyWith(fontSize: 9))),
          Center(
            child: Text(
              glyph,
              style: DojiType.data.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
    if (future) {
      return Semantics(
        label: 'day $day, upcoming',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DashedBorder(radius: 8, child: body),
          ),
        ),
      );
    }
    return DojiPressable(
      onPressed: () => onSelect(day),
      borderRadius: BorderRadius.circular(8),
      selected: isSel,
      semanticLabel:
          'day $day: ${r == null ? 'no trades' : (r.up ? 'up day' : (r.down ? 'down day' : 'flat day'))}',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSel ? DojiColors.textPrimary : border, width: isSel ? 2 : 1.5),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.glyph, required this.color, required this.fill, required this.label});

  final String glyph;
  final Color color;
  final bool fill;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill ? DojiColors.greenTint : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(glyph, style: DojiType.data.copyWith(fontSize: 10, color: color, height: 1)),
      ),
      const SizedBox(width: 5),
      Text(label, style: DojiType.hint.copyWith(fontSize: 10)),
    ],
  );
}
