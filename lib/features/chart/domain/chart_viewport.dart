import 'dart:math' as math;
import 'dart:ui';

import '../../markets/domain/candle.dart';
import 'drawing.dart';

/// Which bars are on screen: [start] is the (fractional) index of the bar at
/// the left edge, [count] how many bars fit. Prices fit the visible bars.
class ChartViewport {
  const ChartViewport({required this.start, required this.count});

  /// The last [count] bars of [total], plus a few empty slots on the right.
  factory ChartViewport.latest(int total, {double count = 60}) =>
      ChartViewport(start: total - count + futureSlots, count: count);

  final double start;
  final double count;

  static const minBars = 12.0;
  static const maxBars = 400.0;

  /// Empty slots kept after the last bar, so a drawing can reach past it.
  static const futureSlots = 16.0;

  /// Moved by [bars] (positive = later), never so far that fewer than five
  /// bars of [total] stay on screen.
  ChartViewport pan(double bars, int total) =>
      ChartViewport(start: _clampStart(start + bars, count, total), count: count);

  /// Zoomed by [factor] (> 1 = closer) around [anchor], the fraction of the
  /// plot width that stays under the pointer (0 = left edge, 1 = right edge).
  ChartViewport zoom(double factor, double anchor, int total) {
    if (factor <= 0) return this;
    final next = (count / factor).clamp(minBars, maxBars);
    final anchorIndex = start + anchor * count;
    return ChartViewport(start: _clampStart(anchorIndex - anchor * next, next, total), count: next);
  }

  static double _clampStart(double start, double count, int total) {
    final lo = math.min(0.0, 5 - count);
    final hi = math.max(lo, total - 5.0);
    return start.clamp(lo, hi);
  }

  @override
  bool operator ==(Object other) => other is ChartViewport && other.start == start && other.count == count;

  @override
  int get hashCode => Object.hash(start, count);
}

/// Pixels ↔ bars, times and prices for one paint. Pure: the painter, the
/// gestures and the hit test all use the same one.
class ChartGeometry {
  ChartGeometry._(this.viewport, this.bars, this.timeframe, this.plot, this.lo, this.hi);

  /// [size] is the whole chart; the right [axis] pixels hold the price tags.
  factory ChartGeometry.of({
    required ChartViewport viewport,
    required List<Candle> bars,
    required Timeframe timeframe,
    required Size size,
    double axis = 56,
  }) {
    final plot = Size(math.max(1, size.width - axis), math.max(1, size.height));
    final first = math.max(0, viewport.start.floor());
    final last = math.min(bars.length, (viewport.start + viewport.count).ceil());
    final visible = first < last ? bars.sublist(first, last) : bars;
    final range = PriceRange.of(visible);
    var hi = range?.high ?? 1, lo = range?.low ?? 0;
    final pad = (hi - lo) * 0.08;
    hi += pad;
    lo -= pad;
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    return ChartGeometry._(viewport, bars, timeframe, plot, lo, hi);
  }

  final ChartViewport viewport;
  final List<Candle> bars;
  final Timeframe timeframe;

  /// The area candles are drawn in (left of the price axis).
  final Size plot;
  final double lo;
  final double hi;

  double get pitch => plot.width / viewport.count;

  double xOfIndex(double i) => (i - viewport.start + 0.5) * pitch;
  double indexOfX(double x) => x / pitch + viewport.start - 0.5;

  double yOf(double price) => (hi - price) / (hi - lo) * plot.height;
  double priceOf(double y) => hi - y / plot.height * (hi - lo);

  double xOf(DateTime t) => xOfIndex(indexOfTime(t));
  Offset offsetOf(ChartPoint p) => Offset(xOf(p.at), yOf(p.price));
  ChartPoint pointAt(Offset o) => ChartPoint(timeOfIndex(indexOfX(o.dx)), priceOf(o.dy));

  /// Fractional bar index of [t]: exact inside the bars (gaps such as
  /// weekends take no room), extrapolated by the timeframe outside them.
  double indexOfTime(DateTime t) {
    final step = timeframe.duration.inMilliseconds;
    if (bars.isEmpty) return 0;
    double frac(DateTime from) => t.difference(from).inMilliseconds / step;
    if (!t.isAfter(bars.first.at)) return frac(bars.first.at);
    if (!t.isBefore(bars.last.at)) return bars.length - 1 + frac(bars.last.at);
    var lo = 0, hi = bars.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (bars[mid].at.isAfter(t)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return lo + math.min(1.0, frac(bars[lo].at));
  }

  /// The time at fractional index [i] (inverse of [indexOfTime]), to the minute.
  DateTime timeOfIndex(double i) {
    final step = timeframe.duration;
    if (bars.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    DateTime from(DateTime base, double bars) => base.add(Duration(minutes: (bars * step.inMinutes).round()));
    if (i <= 0) return from(bars.first.at, i);
    if (i >= bars.length - 1) return from(bars.last.at, i - (bars.length - 1));
    final k = i.floor();
    return from(bars[k].at, i - k);
  }
}
