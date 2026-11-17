import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/journal/domain/trade.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';

import 'journal_fixtures.dart';

/// Twenty trades with known patterns, around local [now]:
/// - 10 london breakout trades opened 09:00, plan kept, +1R each;
/// - 6 range fade trades opened 16:00, plan broken, tagged revenge, −1R each;
/// - 4 wins with no setup opened 09:00, +0.5R each.
List<Trade> insightTrades(DateTime now) {
  final day = DateTime(now.year, now.month, now.day, 17);
  return [
    for (var d = 0; d < 10; d++)
      sampleTrade(
        id: 'lb$d',
        pnl: 50,
        daysAgo: d,
        minutesAgo: 450,
        setup: 'london breakout',
        plan: PlanFollowed.yes,
        now: day,
      ),
    for (var d = 0; d < 6; d++)
      sampleTrade(
        id: 'rf$d',
        pnl: -50,
        daysAgo: d,
        minutesAgo: 30,
        setup: 'range fade',
        plan: PlanFollowed.no,
        mistakes: const ['revenge'],
        now: day,
      ),
    for (var d = 10; d < 14; d++)
      sampleTrade(
        id: 'ns$d',
        pnl: 25,
        daysAgo: d,
        minutesAgo: 450,
        setup: kNoSetup,
        plan: PlanFollowed.no,
        now: day,
      ),
  ];
}

/// An imported, unreviewed EURUSD trade closed an hour before [now].
Trade importedTrade(DateTime now) => Trade(
  id: 'mt5-1',
  symbol: 'EURUSD',
  direction: TradeDirection.long,
  openedAt: now.subtract(const Duration(hours: 2)).toUtc(),
  closedAt: now.subtract(const Duration(hours: 1)).toUtc(),
  entry: 1.1,
  exit: 1.099,
  stop: 1.099,
  size: 0.5,
  pnl: -50,
  riskMoney: 50,
  source: 'mt5',
  accountId: kFirstAccountId,
);
