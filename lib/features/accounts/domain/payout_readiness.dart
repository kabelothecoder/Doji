import '../../journal/domain/trade.dart';
import '../../onboarding/domain/prop_drawdown.dart';
import '../../onboarding/domain/prop_rules.dart';

/// Where a payout rule stands today.
enum RuleStanding {
  kept('kept'),
  close('close'),
  broken('broken'),
  notSet('not set');

  const RuleStanding(this.label);

  /// Shown beside the colour, so colour is never the only signal.
  final String label;
}

/// One payout rule and the distance to it, written in code.
class RuleDistance {
  const RuleDistance({required this.rule, required this.line, required this.standing});

  /// "trading days", "consistency", "daily loss", "drawdown".
  final String rule;

  /// "4 of 5 trading days", "best day is 48% of total gains; the firm allows 40%".
  final String line;
  final RuleStanding standing;
}

/// A limit counts as close from this share of it.
const double kCloseShare = 0.8;

/// The largest positive day as a % of the total gain (all days, net), or
/// null when the total is not above 0. Shared with the backtest's [LimitsCheck].
double? bestDayShare(Iterable<double> dayResults) {
  final days = dayResults.toList();
  final total = days.fold(0.0, (s, d) => s + d);
  if (total <= 0) return null;
  final best = days.fold(0.0, (b, d) => d > b ? d : b);
  return best / total * 100;
}

/// Each closed trade's result summed per local calendar day of its close.
Map<DateTime, double> dayResults(Iterable<Trade> trades) {
  final out = <DateTime, double>{};
  for (final t in trades) {
    final l = t.closedAt.toLocal();
    final d = DateTime(l.year, l.month, l.day);
    out[d] = (out[d] ?? 0) + t.pnl;
  }
  return out;
}

/// The rules that decide a prop payout, measured against the account's own
/// trades. The firm's numbers come from the account editor (no presets).
abstract final class PayoutReadiness {
  /// [trades]: this account's trades. [dailyLossUsedPct] / [dailyLossLimitPct]
  /// and [drawdown] are Home's own figures, so both screens say the same.
  static List<RuleDistance> of({
    required List<Trade> trades,
    required PropRules prop,
    double? dailyLossUsedPct,
    double? dailyLossLimitPct,
    DrawdownStatus? drawdown,
  }) {
    final days = dayResults(trades);
    return [
      _days(days.length, prop.minTradingDays),
      _consistency(days.values, prop.consistencyPct),
      _dailyLoss(dailyLossUsedPct, dailyLossLimitPct ?? prop.dailyLossLimitPct),
      _drawdown(drawdown, prop),
    ];
  }

  static RuleDistance _days(int count, int? min) {
    if (min == null) {
      return RuleDistance(
        rule: 'trading days',
        line: '$count trading ${count == 1 ? 'day' : 'days'} · minimum not set',
        standing: RuleStanding.notSet,
      );
    }
    // Short of the minimum is never a break: it is distance still to go.
    return RuleDistance(
      rule: 'trading days',
      line: count >= min ? '$count of $min trading days · reached' : '$count of $min trading days',
      standing: count >= min ? RuleStanding.kept : RuleStanding.close,
    );
  }

  static RuleDistance _consistency(Iterable<double> days, double? limit) {
    final share = bestDayShare(days);
    if (limit == null) {
      return const RuleDistance(
        rule: 'consistency',
        line: 'consistency rule not set',
        standing: RuleStanding.notSet,
      );
    }
    if (share == null) {
      return RuleDistance(
        rule: 'consistency',
        line: 'no gains yet to measure consistency on; the firm allows ${fmtNum(limit)}%',
        standing: RuleStanding.kept,
      );
    }
    final standing = share > limit
        ? RuleStanding.broken
        : share >= limit * kCloseShare
        ? RuleStanding.close
        : RuleStanding.kept;
    return RuleDistance(
      rule: 'consistency',
      line: 'best day is ${fmtNum(share)}% of total gains; the firm allows ${fmtNum(limit)}%',
      standing: standing,
    );
  }

  static RuleDistance _dailyLoss(double? used, double? limit) {
    if (limit == null || used == null) {
      return const RuleDistance(
        rule: 'daily loss',
        line: 'daily loss limit not set',
        standing: RuleStanding.notSet,
      );
    }
    return RuleDistance(
      rule: 'daily loss',
      line: '${fmtNum(used)}% lost today of ${fmtNum(limit)}% allowed',
      standing: _against(used, limit),
    );
  }

  static RuleDistance _drawdown(DrawdownStatus? d, PropRules prop) {
    if (d == null) {
      return const RuleDistance(
        rule: 'drawdown',
        line: 'max drawdown not set',
        standing: RuleStanding.notSet,
      );
    }
    return RuleDistance(
      rule: 'drawdown',
      line: '${fmtNum(d.usedPct)}% of ${fmtNum(d.limitPct)}% ${prop.drawdownLabel} drawdown used',
      standing: _against(d.usedPct, d.limitPct),
    );
  }

  static RuleStanding _against(double used, double limit) => used >= limit
      ? RuleStanding.broken
      : used >= limit * kCloseShare
      ? RuleStanding.close
      : RuleStanding.kept;
}

/// Whole numbers bare, else at most one decimal: "48", "1.2".
String fmtNum(double v) {
  final r = double.parse(v.toStringAsFixed(1));
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}
