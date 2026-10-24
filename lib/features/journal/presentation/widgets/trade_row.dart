import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/doji_pressable.dart';
import '../../../markets/domain/instrument_catalog.dart';
import '../../domain/formatting.dart';
import '../../domain/journal_stats.dart';
import '../../domain/trade.dart';
import '../../domain/trade_filter.dart';
import 'dashed_border.dart';
import 'mistake_tag_chip.dart';
import 'process_grade_box.dart';

/// Colour of a result: win green, loss orange, flat grey. Always next to a
/// signed number, never alone.
Color resultColor(double pnl) =>
    pnl > 0 ? DojiColors.dojiGreen : (pnl < 0 ? DojiColors.tiltOrange : DojiColors.textSecondary);

/// Doji Trade Journal › `TradeRow`: grade, instrument, direction glyph, result,
/// setup · session · date, and tags. A "! lucky win" or "✓ plan kept" tag is
/// added when the grade and the result disagree.
class TradeRow extends StatelessWidget {
  const TradeRow({
    super.key,
    required this.trade,
    required this.unit,
    required this.currencySymbol,
    required this.onTap,
    this.showSession = true,
  });

  final Trade trade;
  final ResultUnit unit;
  final String currencySymbol;
  final VoidCallback onTap;
  final bool showSession;

  @override
  Widget build(BuildContext context) {
    final t = trade;
    final grade = t.grade;
    final result = tradeResult(t, unit, currencySymbol);
    final setup = t.setup ?? 'not reviewed';
    final detail = [setup, if (showSession) sessionOf(t.openedAt), whenLabel(t.closedAt)].join(' · ');
    final luckyWin = t.isWin && grade != null && grade.brokePlan;
    final planKept = t.isLoss && grade != null && grade.keptPlan;
    return DojiPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(DojiRadius.chip),
      semanticLabel:
          '${instrumentLabel(t.symbol)} ${t.direction.label}, $result, '
          '${grade == null ? 'not graded yet' : 'process grade ${grade.letter}'}, $detail'
          '${luckyWin ? ', lucky win' : ''}${planKept ? ', plan kept' : ''}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DojiColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProcessGradeBox(grade: grade),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          instrumentLabel(t.symbol),
                          overflow: TextOverflow.ellipsis,
                          style: DojiType.data.copyWith(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        t.direction == TradeDirection.long
                            ? Icons.north_east_rounded
                            : Icons.south_east_rounded,
                        size: 14,
                        color: DojiColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(t.direction.label, style: DojiType.callout.copyWith(fontSize: 12)),
                      const Spacer(),
                      Text(result, style: DojiType.data.copyWith(fontSize: 15, color: resultColor(t.pnl))),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(detail, style: DojiType.hint.copyWith(fontSize: 11)),
                  if (!t.reviewed || luckyWin || planKept || t.mistakes.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (!t.reviewed)
                          const _StatusTag('unreviewed', color: DojiColors.textSecondary, dashed: true),
                        if (luckyWin) const _StatusTag('! lucky win', color: DojiColors.tiltOrange),
                        if (planKept) const _StatusTag('✓ plan kept', color: DojiColors.dojiGreen),
                        for (final m in t.mistakes) MistakeTagChip(tag: m),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag(this.text, {required this.color, this.dashed = false});

  final String text;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: DojiType.chip.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: color),
    );
    if (dashed) {
      return DashedBorder(
        radius: 6,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: label,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: label,
    );
  }
}
