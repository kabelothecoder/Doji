import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/backtest/domain/backtest.dart';
import 'package:doji_app/features/gym/domain/gym.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/markets/data/placeholder_rate_source.dart';
import 'package:doji_app/features/markets/domain/candle.dart';
import 'package:doji_app/features/markets/domain/time_zones.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../backtest/backtest_fixtures.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);
  final at = DateTime.utc(2026, 7, 15, 8);

  group('replay practice is scored on process, never on profit', () {
    test('your setup, stop left alone: A (whatever the result)', () {
      final s = scorePractice(
        takes: [PracticeTake(entryAt: at, setupThere: true, stopMoved: false)],
        setups: 1,
      );
      expect(s.grade, ProcessGrade.a);
      expect(s.reasons.every((r) => r.kept), isTrue);
    });

    test('no setup there: F, even if it would have won', () {
      final s = scorePractice(
        takes: [PracticeTake(entryAt: at, setupThere: false, stopMoved: false)],
        setups: 0,
      );
      expect(s.grade, ProcessGrade.f);
    });

    test('stop moved: below A', () {
      final s = scorePractice(
        takes: [PracticeTake(entryAt: at, setupThere: true, stopMoved: true)],
        setups: 1,
      );
      expect(s.grade.keptPlan, isFalse);
    });

    test('past the max trades: the extra one is marked', () {
      final s = scorePractice(
        takes: [
          PracticeTake(entryAt: at, setupThere: true, stopMoved: false),
          PracticeTake(entryAt: at, setupThere: true, stopMoved: false),
        ],
        setups: 2,
        maxTrades: 1,
      );
      expect(s.grade.keptPlan, isFalse);
      expect(s.reasons.any((r) => r.text.contains('past your max')), isTrue);
    });

    test('letting a setup pass is never a mistake', () {
      final s = scorePractice(takes: const [], setups: 2);
      expect(s.grade, ProcessGrade.a);
      expect(s.missed, 2);
    });
  });

  group('after losses: the account\'s own stop-for-the-day rule', () {
    const account = TradingAccount(
      id: 'a',
      name: 'a',
      rules: TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
    );

    test('two losses at 1% reach a 2% limit: no', () {
      final d = afterLossesDrill(account, losses: 2);
      expect(d.yes, isFalse);
      expect(d.explain, contains('daily limit'));
    });

    test('one loss: yes, inside the rules', () {
      expect(afterLossesDrill(account, losses: 1).yes, isTrue);
    });

    test('three losses: the max trades ends the day', () {
      final d = afterLossesDrill(
        account.copyWith(rules: const TradingRules(riskPerTrade: 0.5, maxTradesPerDay: 3, dailyLossLimit: 5)),
        losses: 3,
      );
      expect(d.yes, isFalse);
      expect(d.explain, contains('max'));
    });

    test('the stricter of the prop and own limits counts', () {
      final d = afterLossesDrill(
        account.copyWith(
          rules: const TradingRules(riskPerTrade: 1, dailyLossLimit: 5),
          prop: const PropRules(dailyLossLimitPct: 1),
        ),
        losses: 1,
      );
      expect(d.yes, isFalse);
    });
  });

  test('drills from a backtest: spot, stop, size and after-losses, with checked answers', () {
    final bars = dayBars([(110, 111, 109.5, 110.5), (111, 112, 110.5, 111), (111, 115.5, 110.5, 115)]);
    final result = runBacktest(
      BacktestInput(
        conditions: const [StrategyCondition(kind: ConditionKind.rangeBreak)],
        exits: const ExitRules(),
        timeframe: Timeframe.m15,
        candles: {'EURUSD': bars},
        from: fixtureDay,
        to: fixtureDay.add(const Duration(days: 1)),
      ),
    );
    final items = buildDrills(
      account: const TradingAccount(
        id: 'a',
        name: 'a',
        startingSize: 10000,
        rules: TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
      ),
      result: result,
      history: {'EURUSD': bars},
      timeframe: Timeframe.m15,
      rates: const PlaceholderRateSource(),
      seed: 1,
    );
    final kinds = items.map((i) => i.kind).toSet();
    expect(kinds, containsAll([DrillKind.spotSetup, DrillKind.placeStop, DrillKind.afterLosses]));
    expect(items.length, inInclusiveRange(3, 5));
    final stop = items.firstWhere((i) => i.kind == DrillKind.placeStop);
    expect(stop.checkNumber(109), isTrue);
    expect(stop.checkNumber(105), isFalse);
    final yes = items.firstWhere((i) => i.kind == DrillKind.spotSetup && i.yes == true);
    expect(
      yes.bars.last.at.isBefore(result.trades.single.entryAt),
      isTrue,
      reason: 'frozen before the entry',
    );
  });

  test('drill streak counts back from today, or from yesterday while today is open', () {
    final today = DateTime(2026, 7, 15, 10);
    final days = {DateTime(2026, 7, 13), DateTime(2026, 7, 14)};
    expect(drillStreak(days, today), 2);
    expect(drillStreak({...days, DateTime(2026, 7, 15)}, today), 3);
    expect(drillStreak({DateTime(2026, 7, 12)}, today), 0);
  });
}
