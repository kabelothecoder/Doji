/// Chart timeframes (handoff 1b's control: M5 M15 H1 H4 D1).
enum Timeframe {
  m5('M5', Duration(minutes: 5)),
  m15('M15', Duration(minutes: 15)),
  h1('H1', Duration(hours: 1)),
  h4('H4', Duration(hours: 4)),
  d1('D1', Duration(days: 1));

  const Timeframe(this.label, this.duration);

  final String label;
  final Duration duration;

  /// Spoken name for screen readers ("15 minutes").
  String get spoken => switch (this) {
    m5 => '5 minutes',
    m15 => '15 minutes',
    h1 => '1 hour',
    h4 => '4 hours',
    d1 => '1 day',
  };

  /// The timeframe named in a parsed strategy ('M15', 'm15', '15m', '1h',
  /// 'daily'); null when it names none doji charts.
  static Timeframe? parse(String? text) {
    final t = (text ?? '').toLowerCase().replaceAll(' ', '');
    if (t.isEmpty) return null;
    for (final tf in values) {
      if (t.contains(tf.label.toLowerCase())) return tf;
    }
    if (RegExp(r'\b5m(in)?\b').hasMatch(t)) return m5;
    if (RegExp(r'15m(in)?').hasMatch(t)) return m15;
    if (RegExp(r'\b(1h|60m|hourly)').hasMatch(t)) return h1;
    if (t.contains('4h')) return h4;
    if (t.contains('daily') || t.contains('1d')) return d1;
    return null;
  }

  /// Start of the bar holding [t]: aligned to the timeframe in UTC (D1 bars
  /// start at 00:00 UTC).
  DateTime bucketOf(DateTime t) {
    final ms = t.toUtc().millisecondsSinceEpoch;
    final size = duration.inMilliseconds;
    return DateTime.fromMillisecondsSinceEpoch(ms - ms % size, isUtc: true);
  }
}

/// One bar. Prices are in the instrument's own quote.
class Candle {
  const Candle({
    required this.at,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// Bar open time, UTC.
  final DateTime at;
  final double open;
  final double high;
  final double low;
  final double close;

  /// Closed at or above its open. Drawn light grey, never green: price is neutral.
  bool get up => close >= open;
}

/// The high and low over a window (a session range, a day).
class PriceRange {
  const PriceRange({required this.high, required this.low});

  final double high;
  final double low;

  double get size => high - low;

  /// Over [candles]; null when there are none.
  static PriceRange? of(Iterable<Candle> candles) {
    if (candles.isEmpty) return null;
    var hi = candles.first.high, lo = candles.first.low;
    for (final c in candles) {
      if (c.high > hi) hi = c.high;
      if (c.low < lo) lo = c.low;
    }
    return PriceRange(high: hi, low: lo);
  }
}
