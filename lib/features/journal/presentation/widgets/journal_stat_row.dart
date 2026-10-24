import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../domain/formatting.dart';
import '../../domain/journal_stats.dart';

/// One tile of the stat row.
class JournalStat {
  const JournalStat({required this.label, required this.value, this.color, this.sample = ''});

  final String label;
  final String value;
  final Color? color;

  /// "42 trades", under the value.
  final String sample;
}

/// Doji Trade Journal › `JournalStatRow`: seven stats in Geist Mono with
/// tabular figures and the sample size under each. A horizontal scroll on a
/// phone. The unit follows the R / money toggle.
class JournalStatRow extends StatelessWidget {
  const JournalStatRow({super.key, required this.stats});

  final List<JournalStat> stats;

  /// The seven stats for [s], in [s.unit].
  static List<JournalStat> from(JournalStats s, String symbol) {
    final u = s.unit;
    String v(double? x, {bool signed = true}) => x == null ? '—' : formatValue(x, u, symbol, signed: signed);
    final sample = '${s.count} ${s.count == 1 ? 'trade' : 'trades'}';
    final net = s.net;
    final exp = s.expectancy;
    return [
      JournalStat(
        label: 'net result',
        value: s.count == 0 ? '—' : v(net),
        color: s.count == 0
            ? null
            : (net > 0 ? DojiColors.dojiGreen : (net < 0 ? DojiColors.tiltOrange : null)),
        sample: sample,
      ),
      JournalStat(
        label: 'win rate',
        value: s.winRate == null ? '—' : '${(s.winRate! * 100).round()}%',
        sample: sample,
      ),
      JournalStat(
        label: 'expectancy',
        value: exp == null ? '—' : '${v(exp)}${u == ResultUnit.r ? ' / trade' : ''}',
        color: exp == null
            ? null
            : (exp > 0 ? DojiColors.dojiGreen : (exp < 0 ? DojiColors.tiltOrange : null)),
        sample: sample,
      ),
      JournalStat(
        label: 'profit factor',
        value: s.profitFactor == null ? '—' : s.profitFactor!.toStringAsFixed(2),
        sample: sample,
      ),
      JournalStat(
        label: 'avg win / loss',
        value: s.avgWin == null && s.avgLoss == null
            ? '—'
            : '${s.avgWin == null ? '—' : v(s.avgWin, signed: false)} / ${s.avgLoss == null ? '—' : v(s.avgLoss, signed: false)}',
        sample: sample,
      ),
      JournalStat(
        label: 'max drawdown',
        value: s.count == 0 ? '—' : (s.maxDrawdown < 1e-9 ? v(0, signed: false) : v(-s.maxDrawdown)),
        color: s.maxDrawdown > 1e-9 ? DojiColors.tiltOrange : null,
        sample: sample,
      ),
      JournalStat(
        label: 'rule adherence',
        value: s.adherence == null ? '—' : '${(s.adherence! * 100).round()}%',
        sample: '${s.reviewed} reviewed',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      itemCount: stats.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final s = stats[i];
        return Semantics(
          container: true,
          label: '${s.label}, ${s.value}, ${s.sample}',
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minWidth: 118),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DojiColors.elevated1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DojiColors.separator),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.label, style: DojiType.hint.copyWith(fontSize: 11), maxLines: 1),
                  const SizedBox(height: 6),
                  Text(
                    s.value,
                    maxLines: 1,
                    style: DojiType.data.copyWith(fontSize: 20, color: s.color ?? DojiColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(s.sample, maxLines: 1, style: DojiType.hint.copyWith(fontSize: 10)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
