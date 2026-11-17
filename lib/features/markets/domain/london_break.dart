import '../../onboarding/domain/sessions.dart';
import 'candle.dart';

/// The London open break of the Asian range, read from candles. The brief
/// (live) and the backtest (history) both measure it here, so they agree.
class LondonBreak {
  const LondonBreak({
    required this.range,
    required this.forming,
    required this.londonOver,
    this.breakAt,
    this.retestAt,
    this.up,
  });

  final PriceRange? range;

  /// Before the London open: the range is still being made.
  final bool forming;

  /// After the London close: the setup is done for that day.
  final bool londonOver;

  /// Open time of the bar that first left the range.
  final DateTime? breakAt;

  /// Close time of the first bar that closed back beyond the broken level.
  final DateTime? retestAt;

  /// True when the range high broke, false the low, null with no break.
  final bool? up;

  /// The day's three times, from any instant on or after that day's Tokyo open.
  static ({DateTime tokyoOpen, DateTime londonOpen, DateTime londonClose}) windowFor(DateTime tokyoOpen) => (
    tokyoOpen: tokyoOpen,
    londonOpen: TradingSession.london.openInstant(tokyoOpen)!,
    londonClose: TradingSession.london.closeInstant(tokyoOpen)!,
  );

  /// The latest Tokyo open at or before [now].
  static DateTime lastTokyoOpen(DateTime now) {
    var t = TradingSession.tokyo.openInstant(now)!;
    if (t.isAfter(now)) t = TradingSession.tokyo.openInstant(now.subtract(const Duration(days: 1)))!;
    return t;
  }

  /// [asian] = bars from the Tokyo open to the London open (or [now] while
  /// forming), [london] = bars of [tf] from the London open up to [now] (or
  /// its close). Only bars closed by [now] count as a close back.
  static LondonBreak measure({
    required List<Candle> asian,
    required List<Candle> london,
    required Timeframe tf,
    required DateTime now,
    required DateTime londonOpen,
    required DateTime londonClose,
  }) {
    final forming = now.isBefore(londonOpen);
    final range = PriceRange.of(asian);
    final over = !now.isBefore(londonClose);
    if (range == null || forming) return LondonBreak(range: range, forming: forming, londonOver: over);
    DateTime? breakAt, retestAt;
    bool? up;
    for (final k in london) {
      if (k.at.isBefore(londonOpen) || !k.at.isBefore(londonClose)) continue;
      if (k.at.isAfter(now)) break;
      if (breakAt == null) {
        if (k.high > range.high || k.low < range.low) {
          breakAt = k.at;
          up = k.high > range.high && (k.low >= range.low || k.close >= range.high);
        }
        continue;
      }
      if (k.at.add(tf.duration).isAfter(now)) break;
      final retest = up!
          ? k.low <= range.high && k.close > range.high
          : k.high >= range.low && k.close < range.low;
      if (retest) {
        retestAt = k.at.add(tf.duration);
        break;
      }
    }
    return LondonBreak(
      range: range,
      forming: false,
      londonOver: over,
      breakAt: breakAt,
      retestAt: retestAt,
      up: up,
    );
  }
}
