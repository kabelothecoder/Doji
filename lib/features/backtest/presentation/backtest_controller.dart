import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/domain/condition_eval.dart';
import '../../accounts/domain/trading_account.dart';
import '../../history/history.dart';
import '../../markets/data/routed_market_data.dart';
import '../../markets/data/sample_news_calendar.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/market_data.dart';
import '../../markets/domain/news.dart';
import '../../markets/domain/strategy_reading.dart';
import '../../markets/domain/time_zones.dart';
import '../../markets/presentation/pair_detail_controller.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../data/backtest_repository.dart';
import '../domain/backtest.dart';
import '../domain/refine.dart';

/// The backtest page: the period, the cached history and the last result.
class BacktestView {
  const BacktestView({
    this.days = 90,
    this.loading = false,
    this.error,
    this.history = const {},
    this.result,
    this.end,
  });

  /// Length of the period, ending at today's UTC midnight.
  final int days;
  final bool loading;
  final String? error;
  final Map<String, HistoryRange> history;
  final BacktestResult? result;

  /// The period's end used for [history] (UTC midnight).
  final DateTime? end;

  DateTime get to => end ?? _today();
  DateTime get from => to.subtract(Duration(days: days));

  static DateTime _today() {
    final n = clock.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  BacktestView copyWith({
    int? days,
    bool? loading,
    String? Function()? error,
    Map<String, HistoryRange>? history,
    BacktestResult? Function()? result,
    DateTime? end,
  }) => BacktestView(
    days: days ?? this.days,
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
    history: history ?? this.history,
    result: result == null ? this.result : result(),
    end: end ?? this.end,
  );
}

/// A strategy's conditions; today's default list when it has none saved.
List<StrategyCondition> strategyConditions(StrategyProfile? s) =>
    (s?.conditions.isNotEmpty ?? false) ? s!.conditions : defaultConditions(s?.parsed);

/// The timeframe a strategy is backtested on (its own, M15 when it names none).
Timeframe backtestTimeframe(StrategyProfile? s) => StrategyReading.of(s?.parsed).timeframe;

/// The engine's input for [account] (or a draft's strategy and rules) over
/// [from]–[to] of [history].
BacktestInput backtestInput({
  required ProfileDoji profile,
  required TradingAccount account,
  required Map<String, HistoryRange> history,
  required Map<String, List<NewsEvent>> news,
  required DateTime from,
  required DateTime to,
  StrategyDraft? draft,
}) {
  final strategy = draft?.strategy ?? account.strategy;
  final rules = draft?.rules ?? account.rules;
  final conditions = draft?.activeConditions ?? strategyConditions(strategy);
  final limits = [rules?.dailyLossLimit, account.prop?.dailyLossLimitPct].whereType<double>();
  return BacktestInput(
    conditions: conditions,
    exits: strategy?.exits ?? const ExitRules(),
    timeframe: backtestTimeframe(account.strategy),
    candles: {for (final e in history.entries) e.key: e.value.between(from, to)},
    from: from,
    to: to,
    traderSessions: profile.sessions,
    rules: rules,
    dailyLossLimitPct: limits.isEmpty ? null : limits.reduce((a, b) => a < b ? a : b),
    news: news,
  );
}

class BacktestController extends Notifier<BacktestView> {
  @override
  BacktestView build() => const BacktestView();

  void setDays(int days) => state = state.copyWith(days: days, result: () => null);

  /// News of the sample calendar per symbol, over the period. A symbol with
  /// no news currencies (synthetics) has no news check.
  Future<Map<String, List<NewsEvent>>> news(Iterable<String> symbols, DateTime from, DateTime to) async {
    TimeZones.ensureInitialized();
    final cal = ref.read(newsCalendarProvider);
    return {
      for (final s in symbols)
        if (newsCurrencies(instrumentBySymbol(s)).isNotEmpty)
          s: await cal.highImpact(currencies: newsCurrencies(instrumentBySymbol(s)), from: from, to: to),
    };
  }

  /// Fetches the missing history for the active account's instruments, then
  /// runs the backtest and saves it as a session.
  Future<void> fetchAndRun() async {
    TimeZones.ensureInitialized();
    final profile = ref.read(marketsProfileProvider);
    final account = profile.activeAccount;
    if (account == null) return;
    final end = BacktestView._today();
    state = state.copyWith(loading: true, error: () => null, end: end);
    final tf = backtestTimeframe(account.strategy);
    final from = end.subtract(Duration(days: state.days));
    final service = ref.read(historyServiceProvider);
    final history = <String, HistoryRange>{};
    try {
      for (final s in account.instruments) {
        if (instrumentBySymbol(s) == null) continue; // custom symbols have no feed
        history[s] = await service.ensure(s, tf, from: from, to: end);
      }
    } on FeedUnavailable {
      state = state.copyWith(
        loading: false,
        error: () => 'price feed not responding. what was fetched before is kept.',
      );
      return;
    }
    final news = await this.news(history.keys, from, end);
    final result = runBacktest(
      backtestInput(profile: profile, account: account, history: history, news: news, from: from, to: end),
    );
    state = state.copyWith(loading: false, history: history, result: () => result);
    await ref
        .read(backtestSessionsProvider.notifier)
        .upsert(
          BacktestSession(
            id: 'auto-${account.id}-${clock.now().microsecondsSinceEpoch}',
            accountId: account.id,
            strategyVersion: account.strategyVersion,
            kind: BacktestKind.auto,
            symbols: history.keys.toList(),
            timeframe: tf,
            from: from,
            to: end,
            createdAt: clock.now().toUtc(),
            trades: result.trades,
            label: 'current strategy',
          ),
        );
  }
}

final backtestProvider = NotifierProvider.autoDispose<BacktestController, BacktestView>(
  BacktestController.new,
);

/// Where each symbol's prices come from, for the sample-price warning.
final backtestSourcesProvider = Provider.autoDispose.family<FeedSource, String>(
  (ref, symbol) => ref.watch(marketDataProvider).sourceOf(symbol),
);

/// "sample calendar": the news check uses fixed weekly times, not real releases.
bool newsIsSample(Ref ref) => ref.read(newsCalendarProvider).isSample;
