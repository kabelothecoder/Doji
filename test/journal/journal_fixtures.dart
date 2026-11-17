import 'dart:convert';

import 'package:doji_app/features/journal/data/journal_repository.dart';
import 'package:doji_app/features/onboarding/domain/profile_mapper.dart';
import 'package:doji_app/features/journal/domain/process_grade.dart';
import 'package:doji_app/features/journal/domain/trade.dart';

/// The fixed "now" of the journal tests: a Thursday morning. Trades are built
/// in local time, so "today" never depends on when the suite runs.
final DateTime journalNow = DateTime(2026, 10, 8, 10);

/// A closed XAUUSD trade, [minutesAgo] before [now] (default [journalNow]).
/// Money and R follow from the arguments: risk [risk], result [pnl] (so
/// R = pnl / risk). Taken on the first account unless [accountId] says otherwise.
Trade sampleTrade({
  required String id,
  required double pnl,
  DateTime? now,
  double risk = 50,
  int minutesAgo = 60,
  int daysAgo = 0,
  String symbol = 'XAUUSD',
  TradeDirection direction = TradeDirection.long,
  PlanFollowed? plan,
  String? setup,
  List<String> mistakes = const [],
  TradeEmotion? before,
  TradeEmotion? after,
  String note = '',
  String? accountId = kFirstAccountId,
}) {
  final closed = (now ?? journalNow).subtract(Duration(days: daysAgo, minutes: minutesAgo));
  return Trade(
    id: id,
    symbol: symbol,
    direction: direction,
    openedAt: closed.subtract(const Duration(minutes: 30)).toUtc(),
    closedAt: closed.toUtc(),
    entry: 2000,
    exit: pnl >= 0 ? 2005 : 1995,
    stop: 1995,
    target: 2010,
    size: 0.1,
    pnl: pnl,
    riskMoney: risk,
    setup: setup,
    plan: plan,
    mistakes: mistakes,
    before: before,
    after: after,
    note: note,
    reviewedAt: plan == null ? null : closed.toUtc(),
    accountId: accountId,
  );
}

/// The journal as it sits in shared_preferences.
Map<String, Object> seedJournal(List<Trade> trades) => {
  PrefsJournalRepository.key: jsonEncode({
    'version': PrefsJournalRepository.version,
    'trades': [for (final t in trades) t.toJson()],
  }),
};
