import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/prop_drawdown.dart';
import '../../onboarding/domain/prop_rules.dart';
import 'backtest.dart';

/// A day of a backtest that would have broken a rule.
class DayBreach {
  const DayBreach(this.day, this.reasons);

  /// The UTC date of the trades' entries.
  final DateTime day;
  final List<String> reasons;
}

/// The account's rules replayed over a backtest's trades, closed trades only
/// (open losses inside a day are not on history at this level).
class LimitsCheck {
  const LimitsCheck({required this.breaches, required this.notes, required this.tradingDays});

  final List<DayBreach> breaches;

  /// Whole-sample checks: minimum days, consistency, rules not set.
  final List<String> notes;
  final int tradingDays;

  /// Prop accounts: the firm's daily loss, max drawdown (static or trailing),
  /// minimum days and consistency. Personal accounts: their own daily loss
  /// limit and max trades. Money is % of [startingSize] through [riskPct].
  static LimitsCheck run(
    List<BacktestTrade> trades, {
    PropRules? prop,
    TradingRules? rules,
    double? startingSize,
  }) {
    final size = (startingSize ?? 0) > 0 ? startingSize! : 100.0;
    final risk = rules?.riskPerTrade ?? 1;
    final byDay = <DateTime, List<BacktestTrade>>{};
    for (final t in trades.where((t) => t.closed)) {
      final d = DateTime.utc(t.entryAt.year, t.entryAt.month, t.entryAt.day);
      byDay.putIfAbsent(d, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort();
    final breaches = <DayBreach>[];
    var balance = size, peak = size;
    var best = 0.0, total = 0.0;
    var drawdownBroken = false;
    for (final d in days) {
      final list = byDay[d]!;
      final pct = list.fold(0.0, (s, t) => s + t.r * risk);
      final reasons = <String>[];
      final dailyLimit = prop?.dailyLossLimitPct ?? rules?.dailyLossLimit;
      if (dailyLimit != null && pct < 0 && -pct >= dailyLimit) {
        reasons.add('lost ${_n(-pct)}%: reached the ${_n(dailyLimit)}% daily limit');
      }
      final max = rules?.maxTradesPerDay;
      if (prop == null && max != null && list.length > max) {
        reasons.add('${list.length} trades, your max is $max');
      }
      balance += pct / 100 * size;
      if (balance > peak) peak = balance;
      final money = pct / 100 * size;
      total += money;
      if (money > best) best = money;
      if (prop != null && !drawdownBroken) {
        final dd = PropDrawdown.evaluate(
          prop,
          accountSize: size,
          state: AccountState(balance: balance, equity: balance, peakBalance: peak, peakEquity: peak),
        );
        if (dd != null && dd.breached) {
          drawdownBroken = true;
          reasons.add('${dd.label} past ${_n(dd.limitPct)}%');
        }
      }
      if (reasons.isNotEmpty) breaches.add(DayBreach(d, reasons));
    }
    final notes = <String>[];
    if (prop != null) {
      final minDays = prop.minTradingDays;
      notes.add(
        minDays == null
            ? 'minimum trading days: not set'
            : '${days.length} trading days, the firm asks for $minDays',
      );
      final c = prop.consistencyPct;
      if (c == null) {
        notes.add('consistency rule: not set');
      } else if (total > 0) {
        final share = best / total * 100;
        notes.add(
          share > c
              ? 'best day ${_n(share)}% of the total gain, the rule is ${_n(c)}%: broken'
              : 'best day ${_n(share)}% of the total gain, the rule is ${_n(c)}%: kept',
        );
      } else {
        notes.add('consistency rule: no gain in this sample to measure it on');
      }
      if (prop.maxDrawdownPct == null) notes.add('max drawdown: not set');
    }
    return LimitsCheck(breaches: breaches, notes: notes, tradingDays: days.length);
  }

  static String _n(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }
}
