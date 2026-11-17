import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/walk_away.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journal/journal_fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 15, 15);
  // Oldest first: minutesAgo counts back from [now].
  List<dynamic> day(List<double> pnls) => [
    for (var i = 0; i < pnls.length; i++)
      sampleTrade(id: 't$i', pnl: pnls[i], now: now, minutesAgo: (pnls.length - i) * 30),
  ];
  WalkAway of(List<double> pnls, TradingRules rules) =>
      WalkAway.of(day(pnls).cast(), now, rules: rules, accountSize: 10000);

  test('no rules, nothing reached; result and peak still measured', () {
    final w = of([200, -100], const TradingRules());
    expect(w.hit, isNull);
    expect(w.resultPct, closeTo(1, 1e-9));
    expect(w.peakPct, closeTo(2, 1e-9));
  });

  test('gain cap', () {
    expect(of([150], const TradingRules(dailyGainCap: 2)).hit, isNull);
    expect(of([150, 100], const TradingRules(dailyGainCap: 2)).hit, contains('cap is 2%'));
  });

  test('give-back is measured from the best point of the day', () {
    // Peak +3%, now +1%: two thirds given back.
    expect(of([300, -200], const TradingRules(giveBackPct: 50)).hit, contains('67%'));
    expect(of([300, -100], const TradingRules(giveBackPct: 50)).hit, isNull);
    // A day that never went up has nothing to give back.
    expect(of([-100], const TradingRules(giveBackPct: 50)).hit, isNull);
  });

  test('one and done after the first win', () {
    expect(of([-50], const TradingRules(oneAndDone: true)).hit, isNull);
    expect(of([-50, 80], const TradingRules(oneAndDone: true)).hit, contains('one and done'));
  });

  test("yesterday's trades do not count", () {
    final old = sampleTrade(id: 'y', pnl: 500, now: now, daysAgo: 1);
    expect(
      WalkAway.of([old], now, rules: const TradingRules(dailyGainCap: 2), accountSize: 10000).hit,
      isNull,
    );
  });

  test('without an account size the day is R times the risk per trade', () {
    final w = WalkAway.of(day([100]).cast(), now, rules: const TradingRules(), riskPerTradePct: 0.5);
    expect(w.resultPct, closeTo(1, 1e-9)); // +2R (risk 50) × 0.5%
  });

  test('every line keeps the copy rules', () {
    for (final line in [
      of([300], const TradingRules(dailyGainCap: 2)).hit!,
      of([300, -200], const TradingRules(giveBackPct: 50)).hit!,
      of([80], const TradingRules(oneAndDone: true)).hit!,
    ]) {
      expect(breaksCopyRules(line), isFalse, reason: line);
    }
  });
}
