import '../../journal/domain/trade.dart';
import 'trading_account.dart';

/// Strategy hopping (design/research-intake-plan.md › 1): several changes in a short window leave
/// each version too few trades to judge. A fact for the trader, never a block.
const Duration kHoppingWindow = Duration(days: 42);
const int kHoppingChanges = 2;

/// Fewer trades than this on a version is too few to judge it (same as the backtest's small sample).
const int kTradesToJudge = 30;

/// The line to show for [account], or null when it has not changed strategy often.
String? hoppingLine(TradingAccount account, Iterable<Trade> trades, DateTime now) {
  final recent = account.strategyVersions.where((v) => now.difference(v.replacedAt) <= kHoppingWindow).length;
  if (recent < kHoppingChanges) return null;
  final onCurrent = trades
      .where((t) => t.accountId == account.id && t.strategyVersion == account.strategyVersion)
      .length;
  return '$recent strategy changes in 6 weeks. version ${account.strategyVersion} has $onCurrent '
      "trade${onCurrent == 1 ? '' : 's'}; under $kTradesToJudge is too few to judge it.";
}

/// How often doji asks whether the strategy still fits the trader's week.
const Duration kFitRecheckEvery = Duration(days: 90);

/// True when the trader set their availability and it was last confirmed over 90 days ago.
bool fitRecheckDue({required String? availability, required DateTime? checkedAt, required DateTime now}) =>
    availability != null && checkedAt != null && now.difference(checkedAt) >= kFitRecheckEvery;
