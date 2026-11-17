import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../coach/domain/coach.dart';
import '../../markets/domain/pair_brief.dart';
import '../domain/chart_note.dart';
import 'widgets/chart_sheet.dart';

String _pct(double v) => '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}%';

/// The rows of a pre-trade check: the account's conditions as measured now,
/// then today's limits. A limit row's status is `limitHit` or `ok`.
List<ChecklistAnswer> preTradeRows(List<EntryCondition> conditions, CoachContext c) => [
  for (final x in conditions) ChecklistAnswer(label: x.text, status: x.status.name),
  if (c.maxTradesPerDay != null)
    ChecklistAnswer(
      label: 'trades today ${c.tradesToday} of ${c.maxTradesPerDay}',
      status: c.tradesToday >= c.maxTradesPerDay! ? 'limitHit' : 'ok',
    ),
  if (c.dailyLossLimitPct != null)
    ChecklistAnswer(
      label: 'loss today ${_pct(c.lossTodayPct)} of ${_pct(c.dailyLossLimitPct!)}',
      status: c.lossTodayPct >= c.dailyLossLimitPct! ? 'limitHit' : 'ok',
    ),
  if (c.walkAway != null) const ChecklistAnswer(label: 'walk-away rules', status: 'limitHit'),
  ChecklistAnswer(
    label: 'losses in a row today ${c.lossStreak}',
    status: c.lossStreak >= 2 ? 'limitHit' : 'ok',
  ),
];

/// Plain lines for the limits reached (none = empty).
List<String> limitLines(CoachContext c) => [
  if (c.maxTradesPerDay != null && c.tradesToday >= c.maxTradesPerDay!)
    "you've taken ${c.tradesToday} of ${c.maxTradesPerDay} trades today. your rules say the day is done.",
  if (c.dailyLossLimitPct != null && c.lossTodayPct >= c.dailyLossLimitPct!)
    "you've hit your daily loss limit (${_pct(c.dailyLossLimitPct!)}).",
  ?c.walkAway,
  if (c.lossStreak >= 2) "that's ${c.lossStreak} losses in a row today: the tilt line in your plan.",
];

/// Opens the check for a new position box. Returns the rows with the
/// trader's answers; null when dismissed. Never blocks: "continue" always works.
Future<List<ChecklistAnswer>?> showPreTradeCheck(
  BuildContext context, {
  required List<EntryCondition> conditions,
  required CoachContext coach,
}) => showChartSheet<List<ChecklistAnswer>>(
  context,
  label: 'pre-trade check',
  builder: (_) => PreTradeCheckSheet(rows: preTradeRows(conditions, coach), limits: limitLines(coach)),
);

class PreTradeCheckSheet extends StatefulWidget {
  const PreTradeCheckSheet({super.key, required this.rows, required this.limits});

  final List<ChecklistAnswer> rows;
  final List<String> limits;

  @override
  State<PreTradeCheckSheet> createState() => _PreTradeCheckSheetState();
}

class _PreTradeCheckSheetState extends State<PreTradeCheckSheet> {
  late final List<ChecklistAnswer> _rows = [...widget.rows];

  static String _word(String status) => switch (status) {
    'met' => 'MET',
    'notMet' => 'NOT MET',
    'waiting' => 'WAITING',
    'limitHit' => 'LIMIT REACHED',
    _ => 'OK',
  };

  static Color _color(String status) => switch (status) {
    'met' || 'ok' => DojiColors.dojiGreen,
    'notMet' || 'limitHit' => DojiColors.tiltOrange,
    _ => DojiColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final conditionCount = _rows.where((r) => r.status != 'ok' && r.status != 'limitHit').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('before this trade', style: DojiType.headline)),
        const SizedBox(height: 4),
        Text(
          'your conditions and today\'s limits, measured now. your answers are kept with this position.',
          style: DojiType.callout.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (widget.limits.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DojiRadius.card),
              border: Border.all(color: DojiColors.tiltOrange.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in widget.limits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(l, style: DojiType.body.copyWith(color: DojiColors.textPrimary)),
                  ),
                const SizedBox(height: 6),
                DojiButton(
                  label: 'talk to the coach',
                  variant: DojiButtonVariant.cautionOutline,
                  size: DojiButtonSize.small,
                  onPressed: () {
                    Navigator.of(context).pop(_rows);
                    context.push(Routes.coach);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (conditionCount == 0) Text('no conditions on this account yet.', style: DojiType.hint),
        for (var i = 0; i < _rows.length; i++) _row(i),
        const SizedBox(height: 16),
        DojiButton(label: 'continue', onPressed: () => Navigator.of(context).pop(_rows)),
      ],
    );
  }

  Widget _row(int i) {
    final r = _rows[i];
    final askable = r.status == 'waiting' || r.status == 'notMet';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Expanded(child: Text(r.label, style: DojiType.body)),
                const SizedBox(width: 8),
                Text(_word(r.status), style: DojiType.hint.copyWith(color: _color(r.status), fontSize: 12)),
              ],
            ),
          ),
          if (askable) ...[
            const SizedBox(height: 6),
            Semantics(
              label: 'on your chart: ${r.label}',
              explicitChildNodes: true,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in CheckAnswer.values)
                    DojiChoiceChip(
                      label: a.label,
                      selected: r.answer == a,
                      minHeight: DojiTokens.of(context).minTarget,
                      onTap: () => setState(() => _rows[i] = r.withAnswer(r.answer == a ? null : a)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
