import 'dart:math' as math;

import '../domain/candle.dart';
import '../domain/instrument.dart';
import '../domain/instrument_catalog.dart';
import '../domain/market_data.dart';

/// SAMPLE prices: a smooth, deterministic path per instrument (a few slow
/// waves plus fine noise), so the chart looks like a market, every
/// timeframe agrees with every other, and a test gets the same candles every
/// run. Bars only exist while the instrument's market is open.
///
/// Labelled "sample prices" wherever it shows ([sourceOf]). Never for sizing
/// or decisions. Custom symbols, crypto and anything without a live feed stay here.
class FakeMarketData implements MarketData {
  const FakeMarketData({this.latency = const Duration(milliseconds: 250)});

  /// Simulated network time, so loading states are real.
  final Duration latency;

  @override
  FeedSource sourceOf(String symbol) => const FeedSource.sample();

  /// Rough levels to start the sample path from. Not quotes.
  static const _base = <String, double>{
    'EURUSD': 1.0842,
    'GBPUSD': 1.2731,
    'USDJPY': 151.42,
    'AUDUSD': 0.6612,
    'USDCAD': 1.3684,
    'USDCHF': 0.8815,
    'XAUUSD': 2648.3,
    'XAGUSD': 31.42,
    'NAS100': 20512,
    'US30': 42230,
    'US500': 5841,
    'GER40': 19480,
    'UK100': 8285,
    'USOIL': 71.84,
    'UKOIL': 75.62,
    'BTCUSD': 67420,
    'ETHUSD': 2615,
    'SOLUSD': 162.4,
    'R_10': 6243.18,
    'R_25': 2871.44,
    'R_50': 312.66,
    'R_75': 41860.2,
    'R_100': 1384.52,
    'BOOM300N': 5421.7,
    'BOOM500': 6120.3,
    'BOOM1000': 11842.6,
    'CRASH300N': 4980.4,
    'CRASH500': 5712.9,
    'CRASH1000': 6841.2,
    'ES': 5845.25,
    'NQ': 20530,
    'GC': 2665.4,
    'CL': 71.9,
    'AAPL': 231.4,
    'MSFT': 418.2,
    'TSLA': 251.6,
    'NVDA': 138.1,
  };

  /// How much an instrument moves next to a major forex pair.
  static double _volatility(Instrument i) => switch (i.group) {
    InstrumentGroup.forex => 1,
    InstrumentGroup.metals => 1.6,
    InstrumentGroup.indices || InstrumentGroup.futures => 1.3,
    InstrumentGroup.oil => 2.2,
    InstrumentGroup.crypto => 3,
    InstrumentGroup.stocks => 2,
    InstrumentGroup.boomCrash => 1.5,
    InstrumentGroup.volatility => switch (i.symbol) {
      'R_10' => 0.4,
      'R_25' => 0.8,
      'R_50' => 1.4,
      'R_75' => 2.2,
      _ => 2.8,
    },
  };

  /// Places to show: from the tick size, 2 for synthetics (no tick size yet).
  static int decimalsOf(Instrument i) {
    final tick = i.tickSize;
    if (tick == null || tick <= 0) return 2;
    var places = 0;
    for (var v = tick; v < 1 && places < 8; v *= 10) {
      places++;
    }
    return places;
  }

  Future<void> _wait() => latency > Duration.zero ? Future<void>.delayed(latency) : Future<void>.value();

  @override
  Future<Quote?> quote(String symbol, {required DateTime now}) async {
    await _wait();
    final path = _Path.of(symbol);
    if (path == null) return null;
    final hours = path.instrument.hours;
    final last = hours.lastOpenAtOrBefore(now);
    // Today's trading began at 00:00 UTC, or when the market first opened after it.
    var dayStart = DateTime.utc(last.year, last.month, last.day);
    for (var i = 0; i < 96 && !hours.isOpenAt(dayStart) && dayStart.isBefore(last); i++) {
      dayStart = dayStart.add(const Duration(minutes: 15));
    }
    return Quote(
      symbol: path.instrument.symbol,
      price: path.at(last),
      dayOpen: path.at(dayStart),
      at: last,
      decimals: decimalsOf(path.instrument),
      marketOpen: hours.isOpenAt(now.toUtc()),
    );
  }

  @override
  Future<List<Candle>> candles(String symbol, Timeframe tf, {required DateTime now, int count = 36}) async {
    await _wait();
    final path = _Path.of(symbol);
    if (path == null) return const [];
    final end = now.toUtc();
    final out = <Candle>[];
    var bucket = tf.bucketOf(end);
    // Walk back over closed hours (weekends) until [count] bars are found.
    for (var i = 0; out.length < count && i < count * 4 + 3000; i++) {
      final candle = path.candle(bucket, tf, end);
      if (candle != null) out.add(candle);
      bucket = bucket.subtract(tf.duration);
    }
    return out.reversed.toList();
  }

  @override
  Future<List<Candle>> candlesBetween(
    String symbol,
    Timeframe tf, {
    required DateTime from,
    required DateTime to,
  }) async {
    await _wait();
    final path = _Path.of(symbol);
    if (path == null) return const [];
    final end = to.toUtc();
    final out = <Candle>[];
    for (var bucket = tf.bucketOf(from); bucket.isBefore(end); bucket = bucket.add(tf.duration)) {
      final candle = path.candle(bucket, tf, end);
      if (candle != null) out.add(candle);
    }
    return out;
  }
}

/// One instrument's sample price path: price(t) = base × (1 + vol × wave(t)).
class _Path {
  _Path(this.instrument, this.base, this.vol, this.seed);

  static _Path? of(String symbol) {
    final i = instrumentBySymbol(symbol);
    final base = i == null ? null : FakeMarketData._base[i.symbol];
    if (i == null || base == null) return null;
    var seed = 7;
    for (final c in i.symbol.codeUnits) {
      seed = (seed * 31 + c) & 0x7fffffff;
    }
    return _Path(i, base, FakeMarketData._volatility(i), seed);
  }

  final Instrument instrument;
  final double base;
  final double vol;
  final int seed;

  /// (period in minutes, relative amplitude): slow drift down to fine moves.
  static const _waves = [(41.0, 0.00035), (173.0, 0.0008), (1381.0, 0.0022), (8467.0, 0.0055)];

  double at(DateTime t) {
    final minutes = t.toUtc().millisecondsSinceEpoch / 60000;
    var v = 0.0;
    for (var k = 0; k < _waves.length; k++) {
      final (period, amp) = _waves[k];
      v += amp * math.sin(2 * math.pi * minutes / period + (_hash(seed, k + 1) + 1) * math.pi);
    }
    v += 0.0003 * _noise(minutes / 5);
    return base * (1 + vol * v);
  }

  /// Smooth value noise with a knot every 5 minutes.
  double _noise(double x) {
    final i = x.floor();
    final f = x - i;
    final s = f * f * (3 - 2 * f);
    return _hash(seed, i) * (1 - s) + _hash(seed, i + 1) * s;
  }

  /// Deterministic, -1 to 1.
  static double _hash(int seed, int n) {
    var x = (seed * 374761393 + n * 668265263) & 0x7fffffff;
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
    x ^= x >> 16;
    return (x & 0xffff) / 0xffff * 2 - 1;
  }

  /// The bar starting at [start], cut off at [end] while it is forming. Null
  /// when the market was closed for all of it.
  Candle? candle(DateTime start, Timeframe tf, DateTime end) {
    final hours = instrument.hours;
    final barEnd = start.add(tf.duration);
    final stop = barEnd.isAfter(end) ? end : barEnd;
    if (!stop.isAfter(start)) return null;
    const samples = 12;
    final step = stop.difference(start) ~/ samples;
    final open = at(start), close = at(stop);
    var hi = math.max(open, close), lo = math.min(open, close);
    var traded = hours.isOpenAt(start);
    for (var s = 1; s < samples; s++) {
      final t = start.add(step * s);
      if (!hours.isOpenAt(t)) continue;
      traded = true;
      final p = at(t);
      hi = math.max(hi, p);
      lo = math.min(lo, p);
    }
    if (!traded) return null;
    final n = start.millisecondsSinceEpoch ~/ 60000;
    final wick = base * vol * 0.00012;
    return Candle(
      at: start,
      open: open,
      high: hi + wick * _hash(seed, n).abs(),
      low: lo - wick * _hash(seed, n + 7).abs(),
      close: close,
    );
  }
}
