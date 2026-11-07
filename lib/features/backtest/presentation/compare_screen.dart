import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/condition_eval.dart';
import '../../accounts/domain/trading_account.dart';
import '../../accounts/presentation/accounts_controller.dart';
import '../../history/history.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import '../data/backtest_repository.dart';
import '../domain/backtest.dart';
import '../domain/fills.dart';
import '../domain/limits_check.dart';
import '../domain/refine.dart';
import 'backtest_controller.dart';
import 'widgets/practice_widgets.dart';

/// Both sides of one period: the account's strategy now, and the draft.
class Comparison {
  const Comparison({required this.current, required this.draft, required this.from, required this.to});

  final BacktestResult current;
  final BacktestResult draft;
  final DateTime from;
  final DateTime to;
}

class CompareView {
  const CompareView({this.draft, this.tuning, this.heldBack, this.loading = false});

  final StrategyDraft? draft;
  final Comparison? tuning;
  final Comparison? heldBack;
  final bool loading;
}

/// The refine page's state: one draft, run on the cached history of the
/// account's instruments. The tuning period is the first 70% of it; the last
/// 30% is held back and can be used once.
class CompareController extends Notifier<CompareView> {
  @override
  CompareView build() {
    final account = ref.read(marketsProfileProvider).activeAccount;
    return CompareView(
      draft: account == null
          ? null
          : StrategyDraft.of(account, conditions: strategyConditions(account.strategy)),
    );
  }

  TradingAccount? get _account => ref.read(marketsProfileProvider).activeAccount;

  Map<String, HistoryRange> history() {
    final account = _account;
    if (account == null) return const {};
    final tf = backtestTimeframe(account.strategy);
    final service = ref.read(historyServiceProvider);
    final out = <String, HistoryRange>{};
    for (final s in account.instruments) {
      final h = service.cached(s, tf);
      if (h != null && !h.isEmpty) out[s] = h;
    }
    return out;
  }

  /// The tuning and held-back periods of the cached history (the part every
  /// instrument covers), or null with nothing cached.
  Periods? periods() {
    final h = history();
    if (h.isEmpty) return null;
    final from = h.values.map((r) => r.from).reduce((a, b) => a.isAfter(b) ? a : b);
    final to = h.values.map((r) => r.to).reduce((a, b) => a.isBefore(b) ? a : b);
    if (!to.isAfter(from)) return null;
    return Periods.of(from, to);
  }

  void change(StrategyDraft Function(StrategyDraft) f) {
    final d = state.draft;
    if (d != null) state = CompareView(draft: f(d), tuning: state.tuning, heldBack: state.heldBack);
  }

  Future<Comparison?> _run(DateTime from, DateTime to) async {
    final account = _account;
    final draft = state.draft;
    if (account == null || draft == null) return null;
    final profile = ref.read(marketsProfileProvider);
    final h = history();
    final news = await ref.read(backtestProvider.notifier).news(h.keys, from, to);
    BacktestResult run(StrategyDraft? d) => runBacktest(
      backtestInput(profile: profile, account: account, history: h, news: news, from: from, to: to, draft: d),
    );
    return Comparison(current: run(null), draft: run(draft), from: from, to: to);
  }

  Future<void> runTuning() async {
    final p = periods();
    if (p == null) return;
    state = CompareView(draft: state.draft, tuning: state.tuning, heldBack: state.heldBack, loading: true);
    final c = await _run(p.from, p.split);
    state = CompareView(draft: state.draft?.ran(), tuning: c, heldBack: state.heldBack);
    await _save(c, 'tuning');
  }

  /// Once per draft: both on the held-back period.
  Future<void> runHeldBack() async {
    final p = periods();
    final d = state.draft;
    if (p == null || d == null || d.heldBackSeen) return;
    state = CompareView(draft: d, tuning: state.tuning, loading: true);
    final c = await _run(p.split, p.to);
    state = CompareView(draft: state.draft?.sawHeldBack(), tuning: state.tuning, heldBack: c);
    await _save(c, 'held-back');
  }

  Future<void> _save(Comparison? c, String period) async {
    final account = _account;
    final d = state.draft;
    if (c == null || account == null || d == null) return;
    await ref
        .read(backtestSessionsProvider.notifier)
        .upsert(
          BacktestSession(
            id: 'draft-${account.id}-${clock.now().microsecondsSinceEpoch}',
            accountId: account.id,
            strategyVersion: account.strategyVersion,
            kind: BacktestKind.auto,
            symbols: history().keys.toList(),
            timeframe: backtestTimeframe(account.strategy),
            from: c.from,
            to: c.to,
            createdAt: clock.now().toUtc(),
            trades: c.draft.trades,
            label: 'draft ($period): ${d.changes.isEmpty ? 'no change' : d.changes.join(', ')}',
          ),
        );
  }

  /// The draft becomes the account's strategy; the old one is kept as a version.
  Future<void> adopt() async {
    final account = _account;
    final d = state.draft;
    if (account == null || d == null) return;
    await ref.read(accountsControllerProvider.notifier).save(adoptDraft(account, d, now: clock.now()));
  }
}

final compareProvider = NotifierProvider.autoDispose<CompareController, CompareView>(CompareController.new);

/// Refine the strategy: copy it into a draft, change one thing, run both on
/// the same history and read them side by side. doji never picks a "best":
/// both columns look the same, and the trader decides.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  static const targets = [1.0, 1.5, 2.0, 3.0];
  static const maxTrades = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(compareProvider);
    final c = ref.read(compareProvider.notifier);
    final account = ref.watch(marketsProfileProvider).activeAccount;
    final d = view.draft;
    void back() => context.canPop() ? context.pop() : context.go(Routes.meBacktest);
    if (account == null || d == null) {
      return PracticeScaffold(title: 'refine', onBack: back, children: const [Text('no account yet.')]);
    }
    final periods = c.periods();
    if (periods == null) {
      return PracticeScaffold(
        title: 'refine',
        onBack: back,
        children: [
          Text('no history cached yet. run a backtest first.', style: DojiType.callout),
          const SizedBox(height: 12),
          DojiButton(label: 'go to backtest', size: DojiButtonSize.regular, onPressed: back),
        ],
      );
    }
    final sessionCondition = d.strategy.conditions.where((k) => k.kind == ConditionKind.session).firstOrNull;
    return PracticeScaffold(
      title: 'refine',
      onBack: back,
      children: [
        Text(
          '${account.name} · draft of strategy version ${account.strategyVersion}',
          style: DojiType.callout,
        ),
        HintText(
          'tuning period ${fmtDate(periods.from)} → ${fmtDate(periods.split)}. '
          'held back: ${fmtDate(periods.split)} → ${fmtDate(periods.to)}.',
        ),
        const SizedBox(height: 12),
        PracticeCard(
          label: 'one change at a time',
          children: [
            if (d.pending != null)
              HintText('changed: ${d.changes.last}. run it before changing something else.'),
            _Group(
              title: 'session',
              open: d.canChange(DraftChange.session),
              child: ChipRow<String?>(
                values: [null, for (final s in TradingSession.fixed) s.key],
                selected: sessionCondition?.session,
                label: (k) => k == null ? 'any of yours' : TradingSession.fromKey(k)!.label.toLowerCase(),
                onTap: d.canChange(DraftChange.session) ? (k) => c.change((x) => x.setSession(k)) : null,
              ),
            ),
            _Group(
              title: 'stop',
              open: d.canChange(DraftChange.stop),
              child: ChipRow<StopRule>(
                values: StopRule.values,
                selected: d.exits.stop,
                label: (s) => s.label,
                onTap: d.canChange(DraftChange.stop) ? (s) => c.change((x) => x.setStop(s)) : null,
              ),
            ),
            _Group(
              title: 'target',
              open: d.canChange(DraftChange.target),
              child: ChipRow<double>(
                values: targets,
                selected: d.exits.targetR,
                label: (r) => fmtR(r).replaceFirst('+', ''),
                onTap: d.canChange(DraftChange.target) ? (r) => c.change((x) => x.setTargetR(r)) : null,
              ),
            ),
            _Group(
              title: 'conditions',
              open: d.canChange(DraftChange.condition),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < d.strategy.conditions.length; i++)
                    if (d.strategy.conditions[i].kind != ConditionKind.manual)
                      DojiChoiceChip(
                        label: conditionLabel(d.strategy.conditions[i]),
                        selected: !d.off.contains(i),
                        style: DojiChoiceStyle.chip,
                        onTap: d.canChange(DraftChange.condition)
                            ? () => c.change(
                                (x) => x.toggleCondition(i, conditionLabel(d.strategy.conditions[i])),
                              )
                            : null,
                      ),
                ],
              ),
            ),
            _Group(
              title: 'max trades a day',
              open: d.canChange(DraftChange.maxTrades),
              child: ChipRow<int>(
                values: maxTrades,
                selected: d.rules?.maxTradesPerDay,
                label: (n) => '$n',
                onTap: d.canChange(DraftChange.maxTrades) ? (n) => c.change((x) => x.setMaxTrades(n)) : null,
              ),
            ),
            const SizedBox(height: 12),
            if (view.loading)
              const TerminalLine('running both', cursor: true, liveRegion: true)
            else
              DojiButton(
                label: 'run both on the tuning period',
                size: DojiButtonSize.regular,
                onPressed: () => unawaited(c.runTuning()),
              ),
          ],
        ),
        if (view.tuning case final t?)
          _ComparisonCard(title: 'tuning period', c: t, account: account, draft: d),
        if (view.tuning != null)
          PracticeCard(
            label: 'held-back period',
            children: [
              Text(
                d.heldBackSeen
                    ? 'used once for this draft. a second look would tune to it too.'
                    : 'prices this draft was not tuned on. you can check it there once.',
                style: DojiType.callout,
              ),
              if (!d.heldBackSeen) ...[
                const SizedBox(height: 12),
                DojiButton(
                  label: 'check on the held-back period',
                  variant: DojiButtonVariant.secondary,
                  size: DojiButtonSize.regular,
                  onPressed: view.loading ? null : () => unawaited(c.runHeldBack()),
                ),
              ],
            ],
          ),
        if (view.heldBack case final h?)
          _ComparisonCard(title: 'held-back period', c: h, account: account, draft: d),
        if (view.tuning != null && d.changes.isNotEmpty) ...[
          const SizedBox(height: 4),
          DojiButton(
            label: 'make the draft my strategy',
            variant: DojiButtonVariant.outline,
            size: DojiButtonSize.regular,
            onPressed: () async {
              final ok = await showDojiAlert(
                context,
                title: 'make the draft your strategy?',
                message:
                    'changes: ${d.changes.join(', ')}. version ${account.strategyVersion} is kept in the account editor.',
                destructiveLabel: 'make it my strategy',
              );
              if (!ok) return;
              await c.adopt();
              if (context.mounted) context.go(Routes.meBacktest);
            },
          ),
          const HintText('you decide. doji does not pick a version.'),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.open, required this.child});

  final String title;
  final bool open;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(open ? title : '$title · waits for the run', style: DojiType.label),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.title, required this.c, required this.account, required this.draft});

  final String title;
  final Comparison c;
  final TradingAccount account;
  final StrategyDraft draft;

  @override
  Widget build(BuildContext context) {
    final a = c.current.stats, b = c.draft.stats;
    final la = LimitsCheck.run(
      c.current.trades,
      prop: account.prop,
      rules: account.rules,
      startingSize: account.startingSize,
    );
    final lb = LimitsCheck.run(
      c.draft.trades,
      prop: account.prop,
      rules: draft.rules,
      startingSize: account.startingSize,
    );
    final sa = statRows(a), sb = statRows(b);
    return PracticeCard(
      label: title,
      children: [
        Text('${fmtDate(c.from)} → ${fmtDate(c.to)}, the same prices for both.', style: DojiType.callout),
        const SizedBox(height: 10),
        StatsTable(
          columns: const ['now', 'draft'],
          rows: [
            for (var i = 0; i < sa.length; i++) (sa[i].$1, [sa[i].$2, sb[i].$2]),
            (
              account.prop == null ? 'days that reached your limits' : 'days that broke a prop rule',
              ['${la.breaches.length}', '${lb.breaches.length}'],
            ),
          ],
        ),
        for (final w in fitWarnings(current: a, draft: b, d: draft)) HintText(w),
        for (final x in lb.breaches) HintText('draft, ${fmtDate(x.day)}: ${x.reasons.join('; ')}'),
        for (final n in lb.notes) HintText('draft: $n'),
        if (c.draft.trades.isNotEmpty)
          HintText('instruments: ${c.draft.bySymbol.keys.map(instrumentLabel).join(', ')}'),
        const HintText(kSameBarRule),
      ],
    );
  }
}
