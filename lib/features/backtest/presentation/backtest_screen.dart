import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/condition_eval.dart';
import '../../accounts/domain/trading_account.dart';
import '../../markets/data/sample_news_calendar.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import '../domain/backtest.dart';
import '../domain/fills.dart';
import '../domain/limits_check.dart';
import '../domain/risk_of_ruin.dart';
import 'backtest_controller.dart';
import 'widgets/practice_widgets.dart';

/// The automatic backtest: the active account's measurable conditions over
/// cached history. Results are what happened in this sample, never a
/// forecast; no hit rate, R and counts only.
class BacktestScreen extends ConsumerWidget {
  const BacktestScreen({super.key});

  static const periods = [30, 90, 180];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(marketsProfileProvider);
    final account = profile.activeAccount;
    final view = ref.watch(backtestProvider);
    final c = ref.read(backtestProvider.notifier);
    void back() => context.canPop() ? context.pop() : context.go(Routes.me);
    if (account == null) {
      return PracticeScaffold(title: 'backtest', onBack: back, children: const [Text('no account yet.')]);
    }
    final strategy = account.strategy;
    final conditions = strategyConditions(strategy);
    final exits = strategy?.exits ?? const ExitRules();
    final tf = backtestTimeframe(strategy);
    final result = view.result;
    return PracticeScaffold(
      title: 'backtest',
      onBack: back,
      children: [
        Text(
          '${account.name} · strategy version ${account.strategyVersion} · ${tf.label}',
          style: DojiType.callout,
        ),
        const SizedBox(height: 12),
        PracticeCard(
          label: 'measured',
          children: [
            for (final k in conditions.where((k) => k.kind != ConditionKind.manual))
              Text('· ${conditionLabel(k)}', style: DojiType.callout),
            const SizedBox(height: 8),
            Text(_exitsLine(exits), style: DojiType.callout),
            if (strategy?.exits == null)
              const HintText("doji's defaults. set your own stop and target in the account editor."),
            if (conditions.any((k) => k.kind == ConditionKind.manual)) ...[
              const SizedBox(height: 10),
              Text('not tested, needs replay', style: DojiType.label),
              for (final k in conditions.where((k) => k.kind == ConditionKind.manual))
                Text('· ${k.text ?? ''}', style: DojiType.callout),
            ],
            const SizedBox(height: 12),
            DojiButton(
              label: 'edit strategy',
              variant: DojiButtonVariant.outline,
              size: DojiButtonSize.small,
              expand: false,
              onPressed: () => context.push(Routes.accountEditor(account.id, strategy: true)),
            ),
          ],
        ),
        PracticeCard(
          label: 'history',
          children: [
            Text('period', style: DojiType.callout),
            const SizedBox(height: 8),
            ChipRow<int>(
              values: periods,
              selected: view.days,
              label: (d) => '$d days',
              onTap: view.loading ? null : c.setDays,
            ),
            const SizedBox(height: 10),
            if (account.instruments.isEmpty) const HintText('add instruments from markets first.'),
            for (final e in view.history.entries)
              HintText(
                '${instrumentLabel(e.key)} ${tf.label} · ${fmtDate(e.value.from)} → ${fmtDate(e.value.to)} · '
                '${e.value.candles.length} bars · ${ref.watch(backtestSourcesProvider(e.key)).label}',
              ),
            if (view.error != null) HintText(view.error!),
            const SizedBox(height: 12),
            if (view.loading)
              const TerminalLine('fetching history and running', cursor: true, liveRegion: true)
            else
              DojiButton(
                label: result == null ? 'fetch history and run' : 'run again',
                size: DojiButtonSize.regular,
                onPressed: account.instruments.isEmpty ? null : () => unawaited(c.fetchAndRun()),
              ),
          ],
        ),
        if (result != null) ..._results(context, ref, account, result),
      ],
    );
  }

  static String _exitsLine(ExitRules e) =>
      'stop: ${e.stop.label} (+${(e.bufferOfRange * 100).round()}% of the range) · target ${fmtR(e.targetR).replaceFirst('+', '')}'
      '${e.maxBarsOpen == null ? '' : ' · at most ${e.maxBarsOpen} bars'} · closed at the session end';

  static Widget _ruinCard(TradingAccount account, BacktestResult r) {
    final prop = account.prop;
    final target = prop?.profitTargetPct ?? 100;
    final ruin = prop?.maxDrawdownPct ?? 50;
    final mine = account.rules?.riskPerTrade;
    final risks = {0.5, 1.0, 2.0, 5.0, 10.0, 20.0, ?mine}.toList()..sort();
    final rows = riskOfRuin(
      [for (final t in r.trades.where((t) => t.closed)) t.r],
      risks: risks,
      targetPct: target,
      ruinPct: ruin,
    );
    String pct(double v) => '${v == v.roundToDouble() ? v.toInt() : v}%';
    return PracticeCard(
      label: 'risk of ruin',
      children: [
        Text(
          'these ${r.stats.setups} setups drawn in random order, 1,000 runs of up to 200 trades each. '
          'up ${pct(target)} or down ${pct(ruin)} from the start, whichever comes first.',
          style: DojiType.callout,
        ),
        const SizedBox(height: 10),
        StatsTable(
          columns: ['up ${pct(target)}', 'down ${pct(ruin)}', 'neither'],
          rows: [
            for (final row in rows)
              (
                '${pct(row.riskPct)} a trade${row.riskPct == mine ? ' (yours)' : ''}',
                ['${row.reached}', '${row.ruined}', '${row.neither}'],
              ),
          ],
        ),
        HintText(
          prop == null
              ? 'counts out of 1,000 runs. risk is a % of the starting size. the target and floor are doji\'s '
                    'defaults: set prop rules to use a firm\'s.'
              : 'counts out of 1,000 runs. risk is a % of the starting size, as the firm counts it.',
        ),
        const HintText('same setups, different order. a sample of the past, not a forecast.'),
      ],
    );
  }

  List<Widget> _results(BuildContext context, WidgetRef ref, TradingAccount account, BacktestResult r) {
    final s = r.stats;
    final samplePrices = r.trades
        .map((t) => t.symbol)
        .toSet()
        .any((sym) => !ref.read(backtestSourcesProvider(sym)).live);
    final limits = LimitsCheck.run(
      r.trades,
      prop: account.prop,
      rules: account.rules,
      startingSize: account.startingSize,
    );
    final small = smallSampleLine(s);
    return [
      PracticeCard(
        label: 'what happened',
        children: [
          if (!r.measurableEntry) ...[
            Text(
              'nothing in this strategy marks an entry doji can measure yet. today only a london break of the '
              'asian range is measured. replay your sessions to test it by hand.',
              style: DojiType.callout,
            ),
            const SizedBox(height: 12),
            DojiButton(
              label: 'replay a session',
              variant: DojiButtonVariant.secondary,
              size: DojiButtonSize.regular,
              onPressed: () => context.go(Routes.meReplays),
            ),
          ] else ...[
            Text(sampleLine(s, r.from, r.to), style: DojiType.callout),
            if (small != null) HintText(small),
            const SizedBox(height: 10),
            StatsTable(
              rows: [
                for (final (l, v) in statRows(s)) (l, [v]),
              ],
            ),
            HintText('${r.daysTested} days with prices tested.'),
            if (r.skippedNoRoom > 0)
              HintText('${r.skippedNoRoom} left out: the stop rule put the stop past the entry.'),
            const HintText(kSameBarRule),
            const HintText(kGapRule),
            const HintText(kNoCosts),
            if (ref.read(newsCalendarProvider).isSample)
              const HintText('news check: sample calendar, fixed weekly times, not real releases.'),
            if (samplePrices)
              const HintText(
                'sample prices · not a live feed. results on sample prices are not your market.',
              ),
          ],
        ],
      ),
      if (r.trades.isNotEmpty) ...[
        PracticeCard(
          label: 'by session',
          children: [
            StatsTable(
              columns: const ['setups', 'total', 'streak'],
              rows: [
                for (final e in r.bySession.entries)
                  (
                    TradingSession.fromKey(e.key)?.label.toLowerCase() ?? e.key,
                    ['${e.value.setups}', fmtR(e.value.totalR), '${e.value.maxLosingStreak}'],
                  ),
              ],
            ),
          ],
        ),
        PracticeCard(
          label: 'by instrument',
          children: [
            StatsTable(
              columns: const ['setups', 'total', 'streak'],
              rows: [
                for (final e in r.bySymbol.entries)
                  (
                    instrumentLabel(e.key),
                    ['${e.value.setups}', fmtR(e.value.totalR), '${e.value.maxLosingStreak}'],
                  ),
              ],
            ),
          ],
        ),
      ],
      PracticeCard(
        label: account.prop == null ? 'your limits' : 'prop rules',
        children: [
          if (r.trades.isNotEmpty && limits.breaches.isEmpty)
            Text('no day in this sample broke these rules.', style: DojiType.callout),
          for (final b in limits.breaches)
            Text('${fmtDate(b.day)}: ${b.reasons.join('; ')}', style: DojiType.callout),
          for (final n in limits.notes) HintText(n),
          const HintText('closed trades only: losses open inside a day are not in this check.'),
        ],
      ),
      if (s.setups > 0) _ruinCard(account, r),
      if (r.trades.isNotEmpty)
        PracticeCard(
          label: 'setups',
          children: [
            for (final t in r.trades.reversed.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${fmtDate(t.entryAt)} · ${instrumentLabel(t.symbol)} · ${fmtR(t.r)} (${t.reason.label})',
                        style: DojiType.callout,
                      ),
                    ),
                    DojiButton(
                      label: 'replay',
                      semanticLabel: 'replay ${fmtDate(t.entryAt)} ${instrumentLabel(t.symbol)}',
                      variant: DojiButtonVariant.outline,
                      size: DojiButtonSize.small,
                      expand: false,
                      onPressed: () => context.push(
                        Routes.replay(
                          t.symbol,
                          day: DateTime.utc(t.entryAt.year, t.entryAt.month, t.entryAt.day),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      if (r.measurableEntry)
        DojiButton(
          label: 'refine this strategy',
          variant: DojiButtonVariant.secondary,
          size: DojiButtonSize.regular,
          onPressed: () => context.go(Routes.meCompare),
        ),
    ];
  }
}
