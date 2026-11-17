import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/domain/trading_account.dart';
import '../domain/trade.dart';
import '../presentation/journal_controller.dart';

/// Closed trades from the broker that the journal has not seen yet (Doji Trade Journal Phone ›
/// imported). An imported trade arrives unreviewed with `source` set (mt5, csv…); the journal
/// asks for a 20-second review.
abstract interface class TradeImport {
  /// Trades closed on [account] at the broker; the journal keeps the ones it has not saved.
  Future<List<Trade>> closedTrades(TradingAccount account);
}

/// No broker read yet: nothing arrives. Tests override [tradeImportProvider] with trades.
///
/// TODO(backend): read the linked account's closed deals through the `mt5` function (history
/// deals since the last sync), work out pnl and risk with `TradeMath`, source 'mt5'.
class NoTradeImport implements TradeImport {
  const NoTradeImport();

  @override
  Future<List<Trade>> closedTrades(TradingAccount account) async => const [];
}

final tradeImportProvider = Provider<TradeImport>((ref) => const NoTradeImport());

/// Pulls new closed trades for the active account once per journal visit and saves them.
/// The value is how many were added.
final journalImportProvider = FutureProvider.autoDispose<int>((ref) async {
  final account = ref.read(journalProfileProvider).activeAccount;
  if (account == null) return 0;
  final fetched = await ref.read(tradeImportProvider).closedTrades(account);
  final journal = ref.read(journalControllerProvider.notifier);
  final known = {for (final t in ref.read(journalControllerProvider)) t.id};
  var added = 0;
  for (final t in fetched) {
    if (known.contains(t.id)) continue;
    await journal.add(t);
    added++;
  }
  return added;
});
