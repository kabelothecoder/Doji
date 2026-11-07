import 'package:flutter/material.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/widgets/home_card.dart';
import '../../domain/backtest.dart';

/// "+1.5R", "-0.8R", "0R".
String fmtR(double r) {
  final v = double.parse(r.toStringAsFixed(2));
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  return '${v > 0 ? '+' : ''}${s}R';
}

/// "2026-08-01".
String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// What happened in this sample, with its size: never a forecast.
String sampleLine(BacktestStats s, DateTime from, DateTime to) =>
    'in this sample: ${s.setups} ${s.setups == 1 ? 'setup' : 'setups'}, ${fmtDate(from)} → ${fmtDate(to)}.';

String? smallSampleLine(BacktestStats s) => s.smallSample
    ? 'small sample: ${s.setups} ${s.setups == 1 ? 'setup' : 'setups'}. this shows what happened, not what will.'
    : null;

/// The four numbers every result shows, in order.
List<(String, String)> statRows(BacktestStats s) => [
  ('setups', '${s.setups}'),
  ('total', fmtR(s.totalR)),
  ('average per setup', fmtR(s.averageR)),
  ('longest losing streak', '${s.maxLosingStreak}'),
  ('largest drawdown', fmtR(-s.maxDrawdownR)),
];

/// A screen of the practice area: back, a title, scrolling content.
class PracticeScaffold extends StatelessWidget {
  const PracticeScaffold({super.key, required this.title, required this.children, this.onBack});

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(margin, 12, margin, 32),
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      DojiIconButton(
                        icon: Icons.arrow_back_rounded,
                        semanticLabel: 'back',
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Semantics(header: true, child: Text(title, style: DojiType.title)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card with an optional small caps label.
class PracticeCard extends StatelessWidget {
  const PracticeCard({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Semantics(header: true, child: Text(label!.toUpperCase(), style: DojiType.label)),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    ),
  );
}

/// Label | value rows; several value columns side by side for a comparison.
/// Every column is the same colour: doji never marks a "better" one.
class StatsTable extends StatelessWidget {
  const StatsTable({super.key, required this.rows, this.columns});

  /// (label, values), one value per column.
  final List<(String, List<String>)> rows;

  /// Column titles; null for a single column.
  final List<String>? columns;

  @override
  Widget build(BuildContext context) {
    final cols = columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cols != null)
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: SizedBox()),
                  for (final c in cols)
                    Expanded(
                      flex: 2,
                      child: Text(c, style: DojiType.label, textAlign: TextAlign.end),
                    ),
                ],
              ),
            ),
          ),
        for (final (label, values) in rows)
          Semantics(
            container: true,
            label: cols == null
                ? '$label ${values.first}'
                : '$label: ${[for (var i = 0; i < values.length; i++) '${cols[i]} ${values[i]}'].join(', ')}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Text(label, style: DojiType.callout)),
                    for (final v in values)
                      Expanded(
                        flex: 2,
                        child: Text(v, style: DojiType.data.copyWith(fontSize: 15), textAlign: TextAlign.end),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A short line of plain text in the hint style.
class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: DojiType.hint),
  );
}

/// A row of choice chips that wraps.
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        DojiChoiceChip(
          label: label(v),
          selected: v == selected,
          style: DojiChoiceStyle.chip,
          onTap: onTap == null ? null : () => onTap!(v),
        ),
    ],
  );
}
