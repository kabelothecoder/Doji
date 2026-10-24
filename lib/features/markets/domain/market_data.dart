import 'candle.dart';

/// The latest price of one instrument.
class Quote {
  const Quote({
    required this.symbol,
    required this.price,
    required this.dayOpen,
    required this.at,
    required this.decimals,
    required this.marketOpen,
  });

  final String symbol;
  final double price;

  /// The price when today's (UTC) trading started; "± % today" is from here.
  final double dayOpen;

  /// When [price] was last traded, UTC. Earlier than now while the market is closed.
  final DateTime at;

  /// Places to show the price with.
  final int decimals;
  final bool marketOpen;

  double get changePct => dayOpen == 0 ? 0 : (price - dayOpen) / dayOpen * 100;
}

/// Where prices and candles come from. The UI only sees this.
///
/// [FakeMarketData] is the only implementation: sample prices, labelled as
/// such wherever they show ([isSample]).
/// TODO(next-slice): a real feed. Deriv's websocket (`ticks_history`) for
/// synthetics, a broker or data API for forex, CFDs and crypto, behind a
/// Supabase edge function so keys stay off the device; then stream quotes.
abstract interface class MarketData {
  /// True while prices are sample data; every price on screen says so.
  bool get isSample;

  /// Null when there is no price for [symbol] (custom symbols).
  Future<Quote?> quote(String symbol, {required DateTime now});

  /// The last [count] bars up to [now], oldest first. The last one is still
  /// forming. Bars only exist while the market is open. Empty for unknown symbols.
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36});

  /// Every bar from [from] up to [to] (session ranges, break checks), oldest first.
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  });
}
