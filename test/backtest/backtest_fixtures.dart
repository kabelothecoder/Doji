import 'package:doji_app/features/markets/domain/candle.dart';

/// Wed 2026-07-15 (BST): Tokyo opens 00:00 UTC, London 07:00, London closes 16:00.
final DateTime fixtureDay = DateTime.utc(2026, 7, 15);

Candle bar(DateTime at, double o, double h, double l, double c) =>
    Candle(at: at, open: o, high: h, low: l, close: c);

/// One day of M15 bars for [day]: an Asian range of exactly 100–110 from the
/// Tokyo open to the London open, then [london] (o, h, l, c) from 07:00 UTC,
/// then flat bars at the last close until 16:00.
List<Candle> dayBars(List<(double, double, double, double)> london, {DateTime? day, bool down = false}) {
  final d = day ?? fixtureDay;
  final out = <Candle>[];
  var t = d;
  final londonOpen = d.add(const Duration(hours: 7));
  var i = 0;
  while (t.isBefore(londonOpen)) {
    // Touches 100 and 110 once each, otherwise inside.
    final hi = i == 3 ? 110.0 : 107.0;
    final lo = i == 5 ? 100.0 : 103.0;
    out.add(bar(t, 105, hi, lo, 105));
    t = t.add(const Duration(minutes: 15));
    i++;
  }
  var last = 105.0;
  for (final (o, h, l, c) in london) {
    out.add(bar(t, o, h, l, c));
    last = c;
    t = t.add(const Duration(minutes: 15));
  }
  final close = d.add(const Duration(hours: 16));
  while (t.isBefore(close)) {
    out.add(bar(t, last, last, last, last));
    t = t.add(const Duration(minutes: 15));
  }
  return out;
}
