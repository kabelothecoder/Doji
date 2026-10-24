import '../../onboarding/domain/prop_drawdown.dart';
import 'trade.dart';

/// R (units of planned risk) or money, as the trader picks on the journal.
enum ResultUnit { r, money }

/// The window the journal's stats and curve cover. Calendar-based: "week"
/// starts on Monday, "month" on the 1st.
enum JournalPeriod {
  week('week'),
  month('month'),
  threeMonths('3M'),
  all('all');

  const JournalPeriod(this.label);

  final String label;

  bool contains(DateTime instant, DateTime now) {
    final t = instant.toLocal();
    final n = now.toLocal();
    return switch (this) {
      JournalPeriod.week => !t.isBefore(
        DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1)),
      ),
      JournalPeriod.month => t.year == n.year && t.month == n.month,
      JournalPeriod.threeMonths => !t.isBefore(DateTime(n.year, n.month - 2)),
      JournalPeriod.all => true,
    };
  }
}

/// Trades oldest first, by close time.
List<Trade> chronological(Iterable<Trade> trades) =>
    trades.toList()..sort((a, b) => a.closedAt.compareTo(b.closedAt));

/// The numbers behind the journal's stat row and equity curve, for one set of
/// trades and one [ResultUnit].
///
/// In R, trades without a known risk are left out (and [count] says how many
/// were used), so a figure is never made up for them. Win/loss follows the
/// sign of the result, so it is the same in both units.
class JournalStats {
  const JournalStats({
    required this.unit,
    required this.count,
    required this.net,
    required this.winRate,
    required this.expectancy,
    required this.profitFactor,
    required this.avgWin,
    required this.avgLoss,
    required this.maxDrawdown,
    required this.reviewed,
    required this.keptPlan,
    required this.brokenCount,
    required this.actual,
    required this.ghost,
  });

  final ResultUnit unit;

  /// Trades the figures are based on.
  final int count;
  final double net;

  /// 0–1; null with no trades.
  final double? winRate;
  final double? expectancy;

  /// Gross gains over gross losses; null when there are no losses.
  final double? profitFactor;
  final double? avgWin;

  /// Positive number.
  final double? avgLoss;

  /// Largest fall of the running total from its high, as a positive number.
  final double maxDrawdown;

  /// Reviewed trades, and how many of them kept the plan (grade A or B).
  final int reviewed;
  final int keptPlan;

  /// Trades behind [ghost]'s gap: reviewed and not graded A or B.
  final int brokenCount;

  /// Running total, starting at 0.
  final List<double> actual;

  /// The running total if the trades that broke the plan had not been taken.
  final List<double> ghost;

  double? get adherence => reviewed == 0 ? null : keptPlan / reviewed;

  /// What breaking the plan changed, by the end of the curve: positive when
  /// the plan-breaking trades cost money, negative when they happened to pay.
  double get costOfBreaking => ghost.last - actual.last;

  static double? valueOf(Trade t, ResultUnit unit) => unit == ResultUnit.r ? t.r : t.pnl;

  /// A trade that was reviewed and did not keep the plan (grade C, D or F).
  static bool brokePlan(Trade t) {
    final g = t.grade;
    return g != null && !g.keptPlan;
  }

  factory JournalStats.of(Iterable<Trade> trades, ResultUnit unit) {
    final list = chronological(trades);
    final actual = <double>[0];
    final ghost = <double>[0];
    var wins = 0, losses = 0;
    var gross = 0.0, grossLoss = 0.0, net = 0.0;
    var used = 0, reviewed = 0, kept = 0, broken = 0;
    var peak = 0.0, maxDd = 0.0;
    for (final t in list) {
      if (t.reviewed) {
        reviewed++;
        if (t.grade?.keptPlan ?? false) kept++;
      }
      final v = valueOf(t, unit);
      if (v == null) continue;
      used++;
      net += v;
      if (t.isWin) {
        wins++;
        gross += v;
      } else if (t.isLoss) {
        losses++;
        grossLoss += -v;
      }
      actual.add(actual.last + v);
      final broke = brokePlan(t);
      if (broke) broken++;
      ghost.add(ghost.last + (broke ? 0 : v));
      peak = actual.last > peak ? actual.last : peak;
      final dd = peak - actual.last;
      if (dd > maxDd) maxDd = dd;
    }
    return JournalStats(
      unit: unit,
      count: used,
      net: net,
      winRate: used == 0 ? null : wins / used,
      expectancy: used == 0 ? null : net / used,
      profitFactor: grossLoss > 0 ? gross / grossLoss : null,
      avgWin: wins == 0 ? null : gross / wins,
      avgLoss: losses == 0 ? null : grossLoss / losses,
      maxDrawdown: maxDd,
      reviewed: reviewed,
      keptPlan: kept,
      brokenCount: broken,
      actual: actual,
      ghost: ghost,
    );
  }
}

/// How one calendar day ended: the net result in [unit] and the trade count.
class DayResult {
  const DayResult({required this.net, required this.trades});

  final double net;
  final int trades;

  bool get up => net > 0;
  bool get down => net < 0;
}

/// Results by day of the month [month] (any day in it), keyed by day number.
/// Days with only R-less trades in R mode count their trades but no result.
Map<int, DayResult> calendarMonth(Iterable<Trade> trades, DateTime month, ResultUnit unit) {
  final m = month.toLocal();
  final byDay = <int, (double, int)>{};
  for (final t in trades) {
    final c = t.closedAt.toLocal();
    if (c.year != m.year || c.month != m.month) continue;
    final v = JournalStats.valueOf(t, unit);
    final prev = byDay[c.day] ?? (0.0, 0);
    byDay[c.day] = (prev.$1 + (v ?? 0), prev.$2 + 1);
  }
  return {for (final e in byDay.entries) e.key: DayResult(net: e.value.$1, trades: e.value.$2)};
}

/// Today as the Home rules need it, from the journal.
class DaySummary {
  const DaySummary({required this.count, required this.pnl, required this.r, required this.lossStreak});

  static const empty = DaySummary(count: 0, pnl: 0, r: 0, lossStreak: 0);

  /// Trades closed today.
  final int count;

  /// Net result today, account currency.
  final double pnl;

  /// Net R today, over the trades that have one.
  final double r;

  /// Losses in a row, counting back from the latest trade today.
  final int lossStreak;

  factory DaySummary.of(Iterable<Trade> trades, DateTime now) {
    final n = now.toLocal();
    final today = chronological(
      trades.where((t) {
        final c = t.closedAt.toLocal();
        return c.year == n.year && c.month == n.month && c.day == n.day;
      }),
    );
    var streak = 0;
    for (final t in today.reversed) {
      if (!t.isLoss) break;
      streak++;
    }
    return DaySummary(
      count: today.length,
      pnl: today.fold(0.0, (s, t) => s + t.pnl),
      r: today.fold(0.0, (s, t) => s + (t.r ?? 0)),
      lossStreak: streak,
    );
  }

  /// Today's loss as a percent of the account (0 when the day is flat or up).
  ///
  /// With a known [accountSize] (a prop challenge) it is the money lost over
  /// the account. Otherwise the app has no balance, so it is estimated from R:
  /// the R lost today times the planned risk per trade ([riskPerTradePct]).
  /// TODO(next-slice): the account balance from the broker connection.
  double lossPercent({double? accountSize, required double riskPerTradePct}) {
    if (accountSize != null && accountSize > 0) {
      return pnl >= 0 ? 0 : -pnl / accountSize * 100;
    }
    return r >= 0 ? 0 : -r * riskPerTradePct;
  }
}

/// The account as the journal sees it, for the prop drawdown meter: closed
/// trades only, so equity equals balance (open positions are not tracked yet).
/// TODO(next-slice): equity and its high from the broker.
AccountState accountStateFrom(Iterable<Trade> trades, double startingBalance) {
  var balance = startingBalance;
  var peak = startingBalance;
  for (final t in chronological(trades)) {
    balance += t.pnl;
    if (balance > peak) peak = balance;
  }
  return AccountState(balance: balance, equity: balance, peakBalance: peak, peakEquity: peak);
}
