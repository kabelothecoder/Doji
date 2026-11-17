import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/payout_readiness.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/onboarding/domain/prop_drawdown.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journal/journal_fixtures.dart';

RuleDistance _rule(List<RuleDistance> all, String name) => all.firstWhere((r) => r.rule == name);

DrawdownStatus _dd(double used, double limit) =>
    DrawdownStatus(type: DrawdownType.fixed, basis: null, limitPct: limit, usedPct: used, floor: 0);

void main() {
  const prop = PropRules(minTradingDays: 5, consistencyPct: 40, dailyLossLimitPct: 3, maxDrawdownPct: 6);

  group('trading days', () {
    test('4 of 5: close, never broken', () {
      final trades = [for (var d = 0; d < 4; d++) sampleTrade(id: '$d', pnl: 10, daysAgo: d)];
      final r = _rule(PayoutReadiness.of(trades: trades, prop: prop), 'trading days');
      expect(r.line, '4 of 5 trading days');
      expect(r.standing, RuleStanding.close);
    });

    test('two trades on one day count once; 5 of 5 is reached', () {
      final trades = [
        for (var d = 0; d < 5; d++) sampleTrade(id: '$d', pnl: 10, daysAgo: d),
        sampleTrade(id: 'x', pnl: 10, minutesAgo: 120),
      ];
      final r = _rule(PayoutReadiness.of(trades: trades, prop: prop), 'trading days');
      expect(r.line, '5 of 5 trading days · reached');
      expect(r.standing, RuleStanding.kept);
    });

    test('not set', () {
      final r = _rule(PayoutReadiness.of(trades: const [], prop: const PropRules()), 'trading days');
      expect(r.standing, RuleStanding.notSet);
      expect(r.line, '0 trading days · minimum not set');
    });
  });

  group('consistency', () {
    test('best day 48% of total gains, firm allows 40%: broken', () {
      // Days: +480, +300, +220 = 1000 total; best = 48%.
      final trades = [
        sampleTrade(id: 'a', pnl: 480, daysAgo: 0),
        sampleTrade(id: 'b', pnl: 300, daysAgo: 1),
        sampleTrade(id: 'c', pnl: 220, daysAgo: 2),
      ];
      final r = _rule(PayoutReadiness.of(trades: trades, prop: prop), 'consistency');
      expect(r.line, 'best day is 48% of total gains; the firm allows 40%');
      expect(r.standing, RuleStanding.broken);
    });

    test('losing days count against the total', () {
      // +300, +300, -200 = 400 total; best = 75%.
      expect(bestDayShare([300, 300, -200]), 75);
    });

    test('35% of 40%: close; 20%: kept', () {
      expect(
        _rule(PayoutReadiness.of(trades: _days([35, 35, 30]), prop: prop), 'consistency').standing,
        RuleStanding.close,
      );
      expect(
        _rule(PayoutReadiness.of(trades: _days([20, 20, 20, 20, 20]), prop: prop), 'consistency').standing,
        RuleStanding.kept,
      );
    });

    test('no gains yet', () {
      final r = _rule(PayoutReadiness.of(trades: _days([-10, 5]), prop: prop), 'consistency');
      expect(r.line, 'no gains yet to measure consistency on; the firm allows 40%');
      expect(bestDayShare([-10, 5]), isNull);
    });
  });

  group('daily loss and drawdown', () {
    test('lines and standings', () {
      List<RuleDistance> at(double loss, double dd) => PayoutReadiness.of(
        trades: const [],
        prop: prop,
        dailyLossUsedPct: loss,
        dailyLossLimitPct: 3,
        drawdown: _dd(dd, 6),
      );
      expect(_rule(at(1.2, 2.4), 'daily loss').line, '1.2% lost today of 3% allowed');
      expect(_rule(at(1.2, 2.4), 'daily loss').standing, RuleStanding.kept);
      expect(_rule(at(2.5, 2.4), 'daily loss').standing, RuleStanding.close);
      expect(_rule(at(3, 2.4), 'daily loss').standing, RuleStanding.broken);
      expect(_rule(at(0, 2.4), 'drawdown').line, '2.4% of 6% static drawdown used');
      expect(_rule(at(0, 5), 'drawdown').standing, RuleStanding.close);
      expect(_rule(at(0, 6), 'drawdown').standing, RuleStanding.broken);
    });

    test('not set without a drawdown', () {
      final r = _rule(PayoutReadiness.of(trades: const [], prop: const PropRules()), 'drawdown');
      expect(r.standing, RuleStanding.notSet);
    });
  });

  test('copy rules: every line', () {
    final lines = [
      for (final p in [prop, const PropRules()])
        for (final t in const <List<double>>[
          [],
          [480, 300, 220],
          [-10, 5],
        ])
          ...PayoutReadiness.of(
            trades: _days(t),
            prop: p,
            dailyLossUsedPct: 1,
            dailyLossLimitPct: 3,
            drawdown: _dd(1, 6),
          ).map((r) => r.line),
    ];
    for (final l in lines) {
      expect(breaksCopyRules(l), isFalse, reason: l);
    }
  });
}

/// One trade a day with these results, newest first.
List<Trade> _days(List<double> pnl) => [
  for (var i = 0; i < pnl.length; i++) sampleTrade(id: '$i', pnl: pnl[i], daysAgo: i),
];
