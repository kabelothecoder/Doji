import '../../accounts/domain/trading_account.dart';
import '../../accounts/domain/walk_away.dart';
import '../../journal/domain/guardrails.dart';
import '../../journal/domain/journal_stats.dart';
import '../../journal/domain/plan_kept.dart';
import '../../journal/domain/trade.dart';
import '../../me/domain/me.dart';
import '../../mood/domain/mood.dart';
import '../../onboarding/domain/profile_doji.dart';

/// One scorecard line: what it counts, [kept] of [sample], in words.
/// Discipline only: never money, never a hit rate.
class ScoreLine {
  const ScoreLine({required this.title, required this.counts, required this.kept, required this.sample});

  final String title;

  /// What the line counts, said plainly ("reviewed trades this week").
  final String counts;
  final int kept;
  final int sample;

  bool get empty => sample == 0;

  /// "4 of 5 reviewed trades" or "none yet · reviewed trades".
  String get line => empty ? 'none yet · $counts' : '$kept of $sample $counts';
}

/// The weekly scorecard (design: Doji Me Phone › scorecard), from the journal, the account's
/// rules and mood check-ins. The week starts Monday (local) and runs to [now].
class Scorecard {
  const Scorecard({required this.weekStart, required this.lines});

  final DateTime weekStart;
  final List<ScoreLine> lines;

  static DateTime mondayOf(DateTime now) {
    final l = now.toLocal();
    return DateTime(l.year, l.month, l.day).subtract(Duration(days: l.weekday - 1));
  }

  factory Scorecard.of({
    required List<Trade> trades,
    required TradingAccount? account,
    required List<MoodEntry> moods,
    required DateTime now,
  }) {
    final start = mondayOf(now);
    final end = now.toLocal();
    bool inWeek(DateTime t) {
      final l = t.toLocal();
      return !l.isBefore(start) && !l.isAfter(end);
    }

    final week = trades.where((t) => inWeek(t.closedAt)).toList();

    // Plan kept: the trader's own reviews, summed over the week's versions.
    final plan = PlanKept.byVersion(week, account?.id ?? '');
    final planLine = ScoreLine(
      title: 'plan kept',
      counts: 'reviewed trades',
      kept: plan.fold(0, (s, p) => s + p.kept),
      sample: plan.fold(0, (s, p) => s + p.reviewed),
    );

    final graded = [for (final t in week) ?t.grade];
    final gradeLine = ScoreLine(
      title: 'process grade A or B',
      counts: 'graded trades',
      kept: graded.where((g) => g.keptPlan).length,
      sample: graded.length,
    );

    // shortcut: news near the open is not counted here (the calendar is async), trade detail shows it.
    final guardLine = ScoreLine(
      title: 'no guardrail flags',
      counts: 'trades · stop, risk, trading window',
      kept: week.where((t) => guardrailFlags(t, account: account).isEmpty).length,
      sample: week.length,
    );

    final walk = walkAwayDays(week, account?.rules, accountSize: account?.startingSize);
    final walkLine = ScoreLine(
      title: 'walked away when a rule said so',
      counts: walkAwaySet(account?.rules)
          ? 'days a walk-away rule was reached'
          : 'days · no walk-away rule set',
      kept: walk.where((v) => v).length,
      sample: walk.length,
    );

    final days = keptDays(week);
    final daysLine = ScoreLine(
      title: 'kept days',
      counts: 'reviewed trading days',
      kept: days.values.where((v) => v).length,
      sample: days.length,
    );

    final checkInDays = {
      for (final m in moods)
        if (m.moment == MoodMoment.checkIn && inWeek(m.time))
          DateTime(m.time.toLocal().year, m.time.toLocal().month, m.time.toLocal().day),
    };
    final moodLine = ScoreLine(
      title: 'mood check-ins',
      counts: 'days so far this week',
      kept: checkInDays.length,
      sample: end.difference(start).inDays + 1,
    );

    return Scorecard(weekStart: start, lines: [planLine, gradeLine, guardLine, walkLine, daysLine, moodLine]);
  }
}

bool walkAwaySet(TradingRules? r) =>
    r != null && (r.dailyGainCap != null || r.giveBackPct != null || (r.oneAndDone ?? false));

/// One entry per local day on which a walk-away rule was reached: true when no trade was
/// opened after the close that reached it.
List<bool> walkAwayDays(List<Trade> trades, TradingRules? rules, {double? accountSize}) {
  if (!walkAwaySet(rules)) return const [];
  final byDay = <DateTime, List<Trade>>{};
  for (final t in chronological(trades)) {
    final l = t.closedAt.toLocal();
    (byDay[DateTime(l.year, l.month, l.day)] ??= []).add(t);
  }
  final out = <bool>[];
  for (final day in byDay.values) {
    for (var i = 0; i < day.length; i++) {
      final w = WalkAway.of(
        day.sublist(0, i + 1),
        day[i].closedAt,
        rules: rules,
        accountSize: accountSize,
        riskPerTradePct: rules?.riskPerTrade ?? 1.0,
      );
      if (w.hit != null) {
        out.add(!day.any((t) => t.openedAt.isAfter(day[i].closedAt)));
        break;
      }
    }
  }
  return out;
}
