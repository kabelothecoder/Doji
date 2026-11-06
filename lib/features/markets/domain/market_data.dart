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

/// Where one instrument's prices come from, as the screen says it. The UI
/// shows [label] and never asks which feed it is.
class FeedSource {
  /// Sample prices: every price on screen says so.
  const FeedSource.sample() : live = false, label = 'sample prices · not a live feed';

  /// A real feed, named by where it comes from ('deriv', a broker server).
  const FeedSource.live(String from) : live = true, label = 'live prices · $from';

  final bool live;
  final String label;

  @override
  bool operator ==(Object other) => other is FeedSource && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// A real feed did not answer (dropped socket, broker down). 1b shows its
/// "price feed not responding." state with try again.
class FeedUnavailable implements Exception {
  const FeedUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'FeedUnavailable: $reason';
}

/// Where prices and candles come from. The UI only sees this.
///
/// `RoutedMarketData` is what the app reads: Deriv's public websocket for
/// synthetics, the trader's MT5 account (MetaRPC, through the `mt5` edge
/// function) for forex, metals, indices and oil once the active account has a
/// broker link, and [FakeMarketData]'s sample prices for everything else.
abstract interface class MarketData {
  /// Where [symbol]'s prices come from; the label every price shows.
  FeedSource sourceOf(String symbol);

  /// Null when there is no price for [symbol] (custom symbols). A real feed
  /// that does not answer throws [FeedUnavailable].
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
