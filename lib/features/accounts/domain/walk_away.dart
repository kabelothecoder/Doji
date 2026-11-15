import '../../journal/domain/journal_stats.dart';
import '../../journal/domain/trade.dart';
import '../../onboarding/domain/profile_doji.dart';

/// The walk-away rules (design/research-intake-plan.md › 2): stop for the day after a good day
/// (gain cap), after handing back part of today's best (give-back), or after the first win
/// (one and done). Measured from today's closed trades; never a block, only a line on Home.
class WalkAway {
  const WalkAway({required this.resultPct, required this.peakPct, this.hit});

  /// Today's net result, percent of the account (closed trades).
  final double resultPct;

  /// Today's best running result so far, percent of the account (0 if the day never went up).
  final double peakPct;

  /// The first rule reached, said plainly; null while none is.
  final String? hit;

  /// [accountSize] known: money over the account. Otherwise R times [riskPerTradePct], the same
  /// estimate `DaySummary.lossPercent` uses.
  factory WalkAway.of(
    Iterable<Trade> trades,
    DateTime now, {
    required TradingRules? rules,
    double? accountSize,
    double riskPerTradePct = 1.0,
  }) {
    final n = now.toLocal();
    final today = chronological(
      trades.where((t) {
        final c = t.closedAt.toLocal();
        return c.year == n.year && c.month == n.month && c.day == n.day;
      }),
    );
    double pct(Trade t) =>
        accountSize != null && accountSize > 0 ? t.pnl / accountSize * 100 : (t.r ?? 0) * riskPerTradePct;
    var result = 0.0;
    var peak = 0.0;
    for (final t in today) {
      result += pct(t);
      if (result > peak) peak = result;
    }
    String? hit;
    final cap = rules?.dailyGainCap;
    final giveBack = rules?.giveBackPct;
    if (cap != null && result >= cap) {
      hit = 'up ${_n(result)}% today, your cap is ${_n(cap)}%. done for today.';
    } else if (giveBack != null && peak > 0 && (peak - result) / peak * 100 >= giveBack) {
      hit =
          "you've given back ${((peak - result) / peak * 100).round()}% of today's best (+${_n(peak)}%). "
          'your rule is ${_n(giveBack)}%. done for today.';
    } else if ((rules?.oneAndDone ?? false) && today.any((t) => t.pnl > 0)) {
      hit = 'first win of the day is in. one and done.';
    }
    return WalkAway(resultPct: result, peakPct: peak, hit: hit);
  }
}

/// One decimal at most: 2.5, 3.
String _n(double v) {
  final r = (v * 10).roundToDouble() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}
