import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../backtest/domain/backtest.dart';
import '../../backtest/presentation/backtest_controller.dart';
import '../../backtest/presentation/widgets/practice_widgets.dart';
import '../../history/history.dart';
import '../../markets/data/live_rate_source.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/time_zones.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../markets/presentation/widgets/pair_chart.dart';
import '../data/gym_repository.dart';
import '../domain/gym.dart';

/// Today's drill set, one at a time. Spot / stop / size come from cached
/// history (a backtest fetches it); the after-losses drills only need the
/// account's own limits. Every answer is saved for the gym and the analyst.
class DrillsScreen extends ConsumerStatefulWidget {
  const DrillsScreen({super.key});

  @override
  ConsumerState<DrillsScreen> createState() => _DrillsScreenState();
}

class _DrillsScreenState extends ConsumerState<DrillsScreen> {
  List<DrillItem>? _items;
  bool _historyMissing = false;
  int _i = 0;
  bool? _lastCorrect;
  int _right = 0;
  final _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_build()));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    TimeZones.ensureInitialized();
    final profile = ref.read(marketsProfileProvider);
    final account = profile.activeAccount;
    if (account == null) return;
    final tf = backtestTimeframe(account.strategy);
    final service = ref.read(historyServiceProvider);
    final history = <String, List<Candle>>{};
    for (final s in account.instruments) {
      final h = service.cached(s, tf);
      if (h != null && !h.isEmpty) history[s] = h.candles;
    }
    BacktestResult? result;
    if (history.isNotEmpty) {
      final from = service.cached(history.keys.first, tf)!.from;
      final to = service.cached(history.keys.first, tf)!.to;
      final ranges = {for (final s in history.keys) s: service.cached(s, tf)!};
      final news = await ref.read(backtestProvider.notifier).news(history.keys, from, to);
      result = runBacktest(
        backtestInput(profile: profile, account: account, history: ranges, news: news, from: from, to: to),
      );
      for (final s in history.keys) {
        final q = instrumentBySymbol(s)?.quoteCurrency;
        if (q != null) await ref.read(rateSourceProvider).prepare(q, account.accountCurrency);
      }
    }
    final now = clock.now();
    final items = buildDrills(
      account: account,
      result: result,
      history: history,
      timeframe: tf,
      rates: ref.read(rateSourceProvider),
      seed: now.year * 10000 + now.month * 100 + now.day + account.id.hashCode,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _historyMissing = result == null || result.trades.isEmpty;
    });
  }

  Future<void> _answer(DrillItem item, bool correct, String answer) async {
    setState(() {
      _lastCorrect = correct;
      if (correct) _right++;
    });
    await ref
        .read(gymProvider.notifier)
        .add(
          GymEntry(
            id: 'drill-${clock.now().microsecondsSinceEpoch}',
            at: clock.now().toUtc(),
            accountId: ref.read(marketsProfileProvider).activeAccount?.id ?? 'none',
            kind: GymEntryKind.drill,
            drill: item.kind,
            correct: correct,
            answer: answer,
            symbol: item.symbol,
          ),
        );
  }

  Future<void> _next() async {
    final items = _items!;
    if (_i + 1 >= items.length) {
      await ref
          .read(gymProvider.notifier)
          .add(
            GymEntry(
              id: 'set-${clock.now().microsecondsSinceEpoch}',
              at: clock.now().toUtc(),
              accountId: ref.read(marketsProfileProvider).activeAccount?.id ?? 'none',
              kind: GymEntryKind.drillSet,
              notes: ['$_right of ${items.length}'],
            ),
          );
    }
    setState(() {
      _i++;
      _lastCorrect = null;
      _field.clear();
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.meGym);

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return PracticeScaffold(
        title: 'drills',
        onBack: _back,
        children: const [TerminalLine('setting up the drills', cursor: true, liveRegion: true)],
      );
    }
    if (_i >= items.length) {
      final streak = ref.watch(drillStreakProvider);
      return PracticeScaffold(
        title: 'drills',
        onBack: _back,
        children: [
          Text('set done: $_right of ${items.length}.', style: DojiType.headline),
          HintText('drill streak: $streak ${streak == 1 ? 'day' : 'days'}.'),
          const SizedBox(height: 16),
          DojiButton(label: 'done', size: DojiButtonSize.regular, onPressed: _back),
        ],
      );
    }
    final item = items[_i];
    final answered = _lastCorrect != null;
    final bars = item.bars;
    final decimals = _decimals(item.symbol);
    return PracticeScaffold(
      title: 'drills',
      onBack: _back,
      children: [
        Text('${_i + 1} of ${items.length} · ${item.kind.label}', style: DojiType.label),
        if (_i == 0 && _historyMissing)
          const HintText(
            'spot, stop and size drills need history with measured setups: run a backtest first.',
          ),
        const SizedBox(height: 12),
        if (bars.isNotEmpty) ...[
          if (item.symbol != null) Text(instrumentLabel(item.symbol!), style: DojiType.callout),
          PairChart(
            candles: bars,
            timeframe: backtestTimeframe(ref.read(marketsProfileProvider).strategy),
            decimals: decimals,
            height: 220,
            semanticLabel:
                'frozen chart of ${item.symbol == null ? '' : instrumentLabel(item.symbol!)}, ${bars.length} bars, '
                'last close ${bars.last.close.toStringAsFixed(decimals)}. nothing after the last bar is shown.',
          ),
          const SizedBox(height: 12),
        ],
        Text(item.question, style: DojiType.body),
        const SizedBox(height: 16),
        if (!answered && item.isYesNo)
          Row(
            children: [
              Expanded(
                child: DojiButton(
                  label: 'yes',
                  variant: DojiButtonVariant.secondary,
                  size: DojiButtonSize.regular,
                  onPressed: () => unawaited(_answer(item, item.checkYes(true), 'yes')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DojiButton(
                  label: 'no',
                  variant: DojiButtonVariant.secondary,
                  size: DojiButtonSize.regular,
                  onPressed: () => unawaited(_answer(item, item.checkYes(false), 'no')),
                ),
              ),
            ],
          ),
        if (!answered && !item.isYesNo) ...[
          DojiTextField(
            controller: _field,
            hint: item.kind == DrillKind.sizeTrade ? 'lots' : 'price',
            semanticLabel: item.kind == DrillKind.sizeTrade ? 'size in lots' : 'stop price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DojiButton(
            label: 'check',
            size: DojiButtonSize.regular,
            onPressed: () {
              final v = double.tryParse(_field.text.trim().replaceAll(',', '.'));
              if (v == null) return;
              unawaited(_answer(item, item.checkNumber(v), _field.text.trim()));
            },
          ),
        ],
        if (answered) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(_lastCorrect! ? Icons.check_rounded : Icons.close_rounded, size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastCorrect! ? 'matches your rules' : 'not what your rules say',
                    style: DojiType.headline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(item.explain, style: DojiType.callout),
          const SizedBox(height: 16),
          DojiButton(
            label: _i + 1 >= items.length ? 'finish' : 'next drill',
            size: DojiButtonSize.regular,
            onPressed: () => unawaited(_next()),
          ),
        ],
      ],
    );
  }

  static int _decimals(String? symbol) {
    final tick = symbol == null ? null : instrumentBySymbol(symbol)?.tickSize;
    if (tick == null) return 2;
    final s = tick.toString();
    return s.contains('.') ? s.split('.').last.length : 0;
  }
}
