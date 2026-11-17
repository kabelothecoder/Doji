import 'package:doji_app/core/copy_rules.dart';
import 'package:doji_app/features/accounts/domain/strategy_checks.dart';
import 'package:doji_app/features/accounts/domain/trading_account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journal/journal_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 11, 15);
  TradingAccount withChanges(List<int> daysAgo) => TradingAccount(
    id: 'a',
    name: 'a',
    kind: AccountKind.personal,
    strategyVersions: [
      for (var i = 0; i < daysAgo.length; i++)
        StrategyVersion(
          number: i + 1,
          replacedAt: now.subtract(Duration(days: daysAgo[i])),
        ),
    ],
  );

  test('one change, or old changes, is not hopping', () {
    expect(hoppingLine(withChanges([3]), const [], now), isNull);
    expect(hoppingLine(withChanges([100, 60]), const [], now), isNull);
  });

  test('two changes in six weeks names the trades on the current version', () {
    final a = withChanges([30, 5]);
    final trades = [
      sampleTrade(id: '1', pnl: 1, accountId: 'a').withStrategyVersion(3),
      sampleTrade(id: '2', pnl: 1, accountId: 'a').withStrategyVersion(2),
    ];
    final line = hoppingLine(a, trades, now)!;
    expect(line, contains('2 strategy changes in 6 weeks'));
    expect(line, contains('version 3 has 1 trade;'));
    expect(breaksCopyRules(line), isFalse);
  });

  test('fit re-check every 90 days, only once availability is set', () {
    final old = now.subtract(const Duration(days: 91));
    expect(fitRecheckDue(availability: 'semi_flexible', checkedAt: old, now: now), isTrue);
    expect(fitRecheckDue(availability: 'semi_flexible', checkedAt: now, now: now), isFalse);
    expect(fitRecheckDue(availability: null, checkedAt: old, now: now), isFalse);
    expect(fitRecheckDue(availability: 'semi_flexible', checkedAt: null, now: now), isFalse);
  });
}
