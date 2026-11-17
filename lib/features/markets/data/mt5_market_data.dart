import '../domain/candle.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_data.dart';
import 'fake_market_data.dart';
import 'mt5_api.dart';

/// Real prices for forex, metals, indices and oil from the trader's own MT5
/// account (MetaRPC `SymbolInfoTick` and `QuoteHistory/Bars`, through the
/// `mt5` edge function). Labelled with the broker's server.
///
/// shortcut: asks the broker for the catalogue symbol as-is; brokers that add
/// a suffix ("XAUUSD.m") or rename (US30 = "DJ30") answer with no price. Add a
/// per-link symbol map when a linked broker needs one.
class Mt5MarketData implements MarketData {
  const Mt5MarketData({required this.api, required this.accountRef, required this.server});

  final Mt5Api api;

  /// The [TradingAccount.id] whose broker link answers.
  final String accountRef;
  final String server;

  @override
  FeedSource sourceOf(String symbol) => FeedSource.live(server);

  Future<Map<String, dynamic>> _call(String action, Map<String, Object?> body) async {
    try {
      return await api.call(action, accountRef, body);
    } on Mt5Failure catch (e) {
      throw FeedUnavailable(e.message);
    }
  }

  static int _epoch(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) async {
    final instrument = instrumentBySymbol(symbol);
    if (instrument == null) return null;
    final d = await _call('quote', {'symbol': instrument.symbol});
    final bid = (d['bid'] as num?)?.toDouble();
    if (bid == null || bid <= 0) return null;
    final dayOpen = (d['dayOpen'] as num?)?.toDouble();
    return Quote(
      symbol: instrument.symbol,
      price: bid,
      dayOpen: dayOpen ?? bid,
      at: DateTime.fromMillisecondsSinceEpoch((d['at'] as num?)?.toInt() ?? 0, isUtc: true),
      decimals: FakeMarketData.decimalsOf(instrument),
      marketOpen: instrument.hours.isOpenAt(now.toUtc()),
    );
  }

  Future<List<Candle>> _bars(String symbol, Timeframe tf, DateTime from, DateTime to) async {
    final d = await _call('bars', {'symbol': symbol, 'tf': tf.name, 'from': _epoch(from), 'to': _epoch(to)});
    return [
      for (final b in (d['bars'] as List? ?? const []).whereType<Map<String, dynamic>>())
        Candle(
          at: DateTime.fromMillisecondsSinceEpoch((b['t'] as num).toInt() * 1000, isUtc: true),
          open: (b['o'] as num).toDouble(),
          high: (b['h'] as num).toDouble(),
          low: (b['l'] as num).toDouble(),
          close: (b['c'] as num).toDouble(),
        ),
    ];
  }

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) async {
    final instrument = instrumentBySymbol(symbol);
    if (instrument == null) return const [];
    // Ask for enough calendar time to cover a weekend, then keep the last [count].
    final from = now.subtract(tf.duration * count + const Duration(days: 3));
    final bars = await _bars(instrument.symbol, tf, from, now);
    return bars.length <= count ? bars : bars.sublist(bars.length - count);
  }

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) async {
    final instrument = instrumentBySymbol(symbol);
    if (instrument == null) return const [];
    return _bars(instrument.symbol, tf, from, to);
  }
}
