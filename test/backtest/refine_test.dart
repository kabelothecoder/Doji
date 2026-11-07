import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:doji_app/features/backtest/domain/backtest.dart';
import 'package:doji_app/features/backtest/domain/fills.dart';
import 'package:doji_app/features/backtest/domain/limits_check.dart';
import 'package:doji_app/features/backtest/domain/refine.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _account = TradingAccount(
  id: 'a',
  name: 'prop',
  startingSize: 10000,
  rules: TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
  strategy: StrategyProfile(
    rawText: 'london break',
    conditions: [
      StrategyCondition(kind: ConditionKind.session, session: 'london'),
      StrategyCondition(kind: ConditionKind.rangeBreak),
    ],
  ),
);

/// A closed trade on [day] of July 2026 with [r].
BacktestTrade trade(int day, double r) => BacktestTrade(
  symbol: 'EURUSD',
  session: 'london',
  entryAt: DateTime.utc(2026, 7, day, 8),
  entry: 100,
  stop: 99,
  target: 102,
  exitAt: DateTime.utc(2026, 7, day, 9),
  exit: 100 + r,
  reason: r < 0 ? ExitReason.stop : ExitReason.target,
);

void main() {
  group('a draft changes one thing at a time', () {
    test('after a change, other kinds wait for the run; the same kind replaces the line', () {
      var d = StrategyDraft.of(_account);
      expect(d.exits, const ExitRules(), reason: 'defaults when the account has none');
      d = d.setTargetR(3);
      expect(d.canChange(DraftChange.stop), isFalse);
      expect(identical(d.setStop(StopRule.rangeOpposite), d), isTrue);
      d = d.setTargetR(1.5);
      expect(d.changes, ['target 2R → 1.5R']);
      d = d.ran();
      expect(d.canChange(DraftChange.stop), isTrue);
      d = d.setStop(StopRule.rangeOpposite);
      expect(d.changes, hasLength(2));
    });

    test('a condition switched off is left out of the run and of the adopted strategy', () {
      final d = StrategyDraft.of(_account).toggleCondition(0, 'london session is open');
      expect(d.activeConditions.map((c) => c.kind), [ConditionKind.rangeBreak]);
      expect(d.adopted.conditions, hasLength(1));
      expect(d.toggleCondition(0, 'x').activeConditions, hasLength(2), reason: 'same kind: back on');
    });

    test('adopting keeps the old strategy as a numbered version', () {
      final d = StrategyDraft.of(_account).setTargetR(3).ran();
      final next = adoptDraft(_account, d, now: DateTime.utc(2026, 11, 7));
      expect(next.strategy!.exits!.targetR, 3);
      expect(next.strategyVersion, 2);
      expect(next.strategyVersions.single.number, 1);
      expect(next.strategyVersions.single.strategy, _account.strategy);
      expect(next.strategyVersions.single.note, contains('target 2R → 3R'));
      final third = adoptDraft(
        next,
        StrategyDraft.of(next).setMaxTrades(2).ran(),
        now: DateTime.utc(2026, 11, 8),
      );
      expect(third.strategyVersion, 3);
      expect(third.strategyVersions.map((v) => v.number), [1, 2]);
    });

    test('the held-back period is the last 30% and is used once', () {
      final p = Periods.of(DateTime.utc(2026, 1, 1), DateTime.utc(2026, 1, 11));
      expect(p.split, DateTime.utc(2026, 1, 8));
      final d = StrategyDraft.of(_account).sawHeldBack();
      expect(d.heldBackSeen, isTrue);
    });

    test('fit warnings: small sample, and many changes on one period', () {
      final small = BacktestStats.of([trade(1, 1)]);
      var d = StrategyDraft.of(_account).setTargetR(3).ran().setMaxTrades(2).ran();
      final w = fitWarnings(current: small, draft: small, d: d);
      expect(w.first, contains('small sample'));
      expect(w.last, contains('held-back'));
      d = StrategyDraft.of(_account);
      final big = BacktestStats.of([for (var i = 0; i < 30; i++) trade(1, 1)]);
      expect(fitWarnings(current: big, draft: big, d: d), isEmpty);
    });
  });

  group('the rules replayed over the sample', () {
    test('prop daily loss: the day that reached it', () {
      final c = LimitsCheck.run(
        [trade(1, 1), trade(2, -1), trade(2, -1), trade(3, 2)],
        prop: const PropRules(dailyLossLimitPct: 2),
        rules: _account.rules,
        startingSize: 10000,
      );
      expect(c.breaches.single.day, DateTime.utc(2026, 7, 2));
      expect(c.breaches.single.reasons.single, contains('daily limit'));
    });

    test('static drawdown counts from the start; trailing from the high', () {
      final trades = [trade(1, 3), trade(2, -1), trade(3, -1), trade(4, -1)];
      final fixed = LimitsCheck.run(
        trades,
        prop: const PropRules(maxDrawdownPct: 2.5),
        rules: _account.rules,
      );
      expect(fixed.breaches, isEmpty, reason: 'never 2.5% under the start');
      final trailing = LimitsCheck.run(
        trades,
        prop: const PropRules(maxDrawdownPct: 2.5, drawdownType: DrawdownType.trailing),
        rules: _account.rules,
      );
      expect(trailing.breaches.single.day, DateTime.utc(2026, 7, 4));
    });

    test('consistency and minimum days are said plainly, "not set" when missing', () {
      final trades = [trade(1, 3), trade(2, 1)];
      final c = LimitsCheck.run(
        trades,
        prop: const PropRules(consistencyPct: 50, minTradingDays: 5),
        rules: _account.rules,
      );
      expect(c.notes, contains('2 trading days, the firm asks for 5'));
      expect(c.notes.any((n) => n.contains('75%') && n.endsWith('broken')), isTrue);
      final unset = LimitsCheck.run(trades, prop: const PropRules(), rules: _account.rules);
      expect(unset.notes, containsAll(['minimum trading days: not set', 'consistency rule: not set']));
    });

    test('a personal account: its own daily limit and max trades', () {
      final c = LimitsCheck.run([
        trade(1, -1),
        trade(1, -1),
        trade(1, -1),
        trade(1, -1),
      ], rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2));
      expect(c.breaches.single.reasons, hasLength(2));
    });
  });
}
