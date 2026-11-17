import '../../onboarding/domain/profile_doji.dart';
import 'candle.dart';

/// How far doji can measure a strategy on the chart.
enum StrategyKind {
  /// A break of the Asian range in London: the range, the break and the
  /// retest close are all measurable from candles.
  londonBreak,

  /// Described, but not something doji can read from candles yet: its entry
  /// shows as "waiting" and the trader checks it on their own chart.
  other,

  /// No strategy described: the brief checks the rules only.
  none,
}

/// The parsed strategy (profile.doji › strategy.parsed) as the brief uses it.
class StrategyReading {
  const StrategyReading({required this.kind, required this.timeframe, this.setup, this.entry});

  factory StrategyReading.of(ParsedStrategy? p) {
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim().toLowerCase();
    final setup = clean(p?.setup), entry = clean(p?.entry);
    final timeframe = Timeframe.parse(p?.timeframe) ?? Timeframe.m15;
    if (p == null || p.isEmpty) {
      return StrategyReading(kind: StrategyKind.none, timeframe: timeframe);
    }
    final asian = (setup ?? '').contains('asian') && (setup ?? '').contains('range');
    final kind = p.slug == 'london_break' || asian ? StrategyKind.londonBreak : StrategyKind.other;
    return StrategyReading(kind: kind, timeframe: timeframe, setup: setup, entry: entry);
  }

  final StrategyKind kind;

  /// The entry timeframe: the strategy's own, else M15.
  final Timeframe timeframe;

  /// Lowercase, in the trader's words.
  final String? setup;
  final String? entry;

  /// The entry waits for price to come back to a level.
  bool get retest => (entry ?? '').contains('retest');
}
