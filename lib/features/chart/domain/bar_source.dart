import '../../markets/domain/candle.dart';
import '../../markets/domain/market_data.dart';

/// Where the chart's bars come from. The live feed now; backtest replay and
/// the gym later give their own, and the chart does not change.
abstract interface class BarSource {
  /// The label every price on the chart shows ("live prices · deriv").
  FeedSource get source;

  /// The last [count] bars up to [now], oldest first. Throws
  /// [FeedUnavailable] when a real feed does not answer.
  Future<List<Candle>> bars(Timeframe tf, {required DateTime now, int count});
}

/// [MarketData] (slice 02's routed feed) for one symbol.
class LiveBarSource implements BarSource {
  const LiveBarSource(this._market, this.symbol);

  final MarketData _market;
  final String symbol;

  @override
  FeedSource get source => _market.sourceOf(symbol);

  @override
  Future<List<Candle>> bars(Timeframe tf, {required DateTime now, int count = 300}) =>
      _market.candles(symbol, tf, now: now, count: count);
}
