import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/backtest/domain/backtest.dart';
import 'package:doji_app/features/backtest/domain/fills.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/news.dart';
import 'package:doji_app/features/markets/domain/time_zones.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backtest_fixtures.dart';

const _break = [StrategyCondition(kind: ConditionKind.rangeBreak)];

BacktestResult run(
  Map<String, List<Candle>> candles, {
  List<StrategyCondition> conditions = _break,
  ExitRules exits = const ExitRules(),
  TradingRules? rules,
  double? limit,
  Map<String, List<NewsEvent>> news = const {},
}) => runBacktest(
  BacktestInput(
    conditions: conditions,
    exits: exits,
    timeframe: Timeframe.m15,
    candles: candles,
    from: fixtureDay,
    to: fixtureDay.add(const Duration(days: 1)),
    rules: rules,
    dailyLossLimitPct: limit,
    news: news,
  ),
);

void main() {
  setUpAll(TimeZones.ensureInitialized);

  // The break bar at 07:00 leaves 100–110 upward; entry is 07:15's open (111).
  // Stop past the broken level: 110 - 10% of the range = 109, so 1R = 2 and
  // the 2R target is 115.
  group('one london break, known answers', () {
    test('target reached: +2R', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 112, 110, 111.5), (111.5, 115.5, 111, 115)]),
      });
      expect(r.trades, hasLength(1));
      final t = r.trades.single;
      expect(t.entry, 111);
      expect(t.stop, closeTo(109, 1e-9));
      expect(t.target, closeTo(115, 1e-9));
      expect(t.reason, ExitReason.target);
      expect(t.r, closeTo(2, 1e-9));
      expect(t.session, 'london');
    });

    test('stop reached: -1R', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 111.5, 108.5, 109)]),
      });
      expect(r.trades.single.reason, ExitReason.stop);
      expect(r.trades.single.r, closeTo(-1, 1e-9));
    });

    test('stop and target inside the same bar: the stop', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 116, 108, 112)]),
      });
      expect(r.trades.single.reason, ExitReason.stop);
      expect(r.trades.single.r, closeTo(-1, 1e-9));
    });

    test('a gap past the stop fills at the open: more than 1R', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 111.5, 110.5, 111), (107, 107.5, 106, 107)]),
      });
      expect(r.trades.single.exit, 107);
      expect(r.trades.single.r, closeTo(-2, 1e-9));
    });

    test('time limit closes at the close of the last bar', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 112, 110.5, 111.5), (111.5, 112.5, 111, 112)]),
      }, exits: const ExitRules(maxBarsOpen: 2));
      expect(r.trades.single.reason, ExitReason.maxBars);
      expect(r.trades.single.r, closeTo(0.5, 1e-9));
    });

    test('neither hit: closed at the session end', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 112, 110.5, 112)]),
      });
      expect(r.trades.single.reason, ExitReason.sessionEnd);
      expect(r.trades.single.r, closeTo(0.5, 1e-9));
    });

    test('the other side of the range: stop 99, target 135', () {
      final r = run({
        'EURUSD': dayBars([(110, 111, 109.5, 110.5), (111, 112, 110.5, 111)]),
      }, exits: const ExitRules(stop: StopRule.rangeOpposite));
      expect(r.trades.single.stop, closeTo(99, 1e-9));
      expect(r.trades.single.target, closeTo(135, 1e-9));
    });

    test('a break of the low: stop above the entry', () {
      final r = run({
        'EURUSD': dayBars([(100, 100.5, 99, 99.5), (99, 99.5, 94.5, 95)]),
      });
      final t = r.trades.single;
      expect(t.stopBelow, isFalse);
      expect(t.stop, closeTo(101, 1e-9));
      expect(t.reason, ExitReason.target); // 99 - 2 * 2 = 95
      expect(t.r, closeTo(2, 1e-9));
    });

    test('with the close back, entry waits for the retest close', () {
      final r = run(
        {
          'EURUSD': dayBars([(110, 111, 109.5, 110.8), (110.8, 111, 109.8, 110.6), (110.6, 112, 110.4, 111)]),
        },
        conditions: const [StrategyCondition(kind: ConditionKind.rangeBreak, closeBack: true)],
      );
      // 07:15 dips to 109.8 and closes 110.6 > 110: the retest; entry 07:30 open.
      expect(r.trades.single.entryAt, fixtureDay.add(const Duration(hours: 7, minutes: 30)));
      expect(r.trades.single.entry, 110.6);
    });
  });

  group('limits across a day', () {
    final loses = dayBars([(110, 111, 109.5, 110.5), (111, 111.5, 108.5, 109)]);
    // The second instrument breaks an hour later.
    final later = dayBars([
      for (var i = 0; i < 4; i++) (105.0, 106.0, 104.0, 105.0),
      (110, 111, 109.5, 110.5),
      (111, 115.5, 110.5, 115),
    ]);

    test('max trades: one a day', () {
      final r = run({'EURUSD': loses, 'GBPUSD': later}, rules: const TradingRules(maxTradesPerDay: 1));
      expect(r.trades.map((t) => t.symbol), ['EURUSD']);
    });

    test('daily loss limit reached: no more setups that day', () {
      final r = run({'EURUSD': loses, 'GBPUSD': later}, rules: const TradingRules(riskPerTrade: 1), limit: 1);
      expect(r.trades.map((t) => t.symbol), ['EURUSD']);
    });

    test('limits not reached: both', () {
      final r = run({'EURUSD': loses, 'GBPUSD': later}, rules: const TradingRules(riskPerTrade: 1), limit: 3);
      expect(r.trades.map((t) => t.symbol), ['EURUSD', 'GBPUSD']);
      expect(r.bySymbol['GBPUSD']!.totalR, closeTo(2, 1e-9));
    });

    test('news inside the window at entry: no setup', () {
      final at = fixtureDay.add(const Duration(hours: 7, minutes: 30));
      final r = run(
        {'EURUSD': loses},
        conditions: const [
          ..._break,
          StrategyCondition(kind: ConditionKind.newsBuffer),
        ],
        news: {
          'EURUSD': [NewsEvent(at: at, currency: 'USD', title: 'usd release')],
        },
      );
      expect(r.trades, isEmpty);
    });
  });

  test('manual conditions are listed, never tested; no measurable entry = no setups', () {
    final r = run(
      {
        'EURUSD': dayBars([(110, 111, 109.5, 110.5)]),
      },
      conditions: const [
        StrategyCondition(kind: ConditionKind.session, session: 'london'),
        StrategyCondition(kind: ConditionKind.manual, text: 'engulfing candle at the level'),
      ],
    );
    expect(r.measurableEntry, isFalse);
    expect(r.trades, isEmpty);
    expect(r.untested, ['engulfing candle at the level']);
  });

  test('a manual condition next to a range break does not block the measured setup', () {
    final r = run(
      {
        'EURUSD': dayBars([(110, 111, 109.5, 110.5)]),
      },
      conditions: const [
        ..._break,
        StrategyCondition(kind: ConditionKind.manual, text: 'my entry candle'),
      ],
    );
    expect(r.trades, hasLength(1));
    expect(r.untested, ['my entry candle']);
  });

  test('stats: total, average, losing streak, drawdown in R, small sample', () {
    BacktestTrade t(double exit) => BacktestTrade(
      symbol: 'X',
      session: 'london',
      entryAt: fixtureDay,
      entry: 100,
      stop: 99,
      target: 102,
      exitAt: fixtureDay,
      exit: exit,
      reason: ExitReason.target,
    );
    // +2, -1, -1, -1, +2 → total 1, streak 3, drawdown 3 (from 2 to -1).
    final s = BacktestStats.of([t(102), t(99), t(99), t(99), t(102)]);
    expect(s.setups, 5);
    expect(s.totalR, closeTo(1, 1e-9));
    expect(s.averageR, closeTo(0.2, 1e-9));
    expect(s.maxLosingStreak, 3);
    expect(s.maxDrawdownR, closeTo(3, 1e-9));
    expect(s.smallSample, isTrue);
  });

  test('a quiet day with no break: no setup, the day still counts', () {
    final r = run({'EURUSD': dayBars([])});
    expect(r.trades, isEmpty);
    expect(r.daysTested, 1);
  });
}
