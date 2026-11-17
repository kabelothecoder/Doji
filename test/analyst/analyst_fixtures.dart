import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/onboarding/domain/profile_doji.dart';
import 'package:doji_app/features/onboarding/domain/prop_rules.dart';
import 'package:doji_app/features/journal/domain/trade.dart';

import '../helpers/app_harness.dart';
import '../helpers/clocks.dart';
import '../helpers/sample_profile.dart';
import '../journal/journal_fixtures.dart';

/// Wed 2026-07-15, BST: London's session is 07:00–16:00 UTC, Tokyo's 00:00–09:00.
final DateTime analystDay = DateTime.utc(2026, 7, 15);

/// A trade opened at [open] (UTC), closed 30 minutes later, risk 50 so
/// R = pnl / 50. Reviewed when [plan] is given.
Trade at(
  String id,
  DateTime open,
  double pnl, {
  PlanFollowed? plan,
  List<String> mistakes = const [],
  String symbol = 'EURUSD',
  double? risk = 50,
  String? setup,
}) => Trade(
  id: id,
  symbol: symbol,
  direction: TradeDirection.long,
  openedAt: open,
  closedAt: open.add(const Duration(minutes: 30)),
  entry: 1,
  exit: 1,
  size: 1,
  pnl: pnl,
  riskMoney: risk,
  plan: plan,
  mistakes: mistakes,
  setup: setup,
  reviewedAt: plan == null ? null : open.add(const Duration(hours: 1)),
  accountId: 'acc',
);

/// [h]:[m] UTC on [analystDay] plus [day] days.
DateTime utc(int h, [int m = 0, int day = 0]) => analystDay.add(Duration(days: day, hours: h, minutes: m));

/// [n] reviewed trades last week (summerDay is Wed 2026-07-15), each tagged revenge.
List<Trade> lastWeekTrades(int n) => [
  for (var i = 0; i < n; i++)
    sampleTrade(
      id: 't$i',
      pnl: i.isEven ? 50 : -50,
      now: summerDay.now(),
      daysAgo: 3 + i % 6,
      minutesAgo: 60 + i * 5,
      plan: PlanFollowed.no,
      mistakes: const ['revenge'],
    ),
];

Map<String, Object> propSeed() => seedProfile(
  profile: profileWith(
    name: 'sam',
    instruments: const ['EURUSD'],
    sessions: const ['london'],
    timeZone: 'Africa/Johannesburg',
    utcOffsetMinutes: 120,
    startingSize: 10000,
    rules: const TradingRules(riskPerTrade: 1, maxTradesPerDay: 3, dailyLossLimit: 2),
    prop: const PropRules(minTradingDays: 5, consistencyPct: 40, dailyLossLimitPct: 3, maxDrawdownPct: 6),
    pledgedAt: DateTime.utc(2026, 7, 1),
    completedAt: DateTime.utc(2026, 7, 1),
  ),
);
