import '../../accounts/domain/payout_readiness.dart';
import '../../backtest/data/backtest_repository.dart';
import '../../chart/data/copilot_service.dart';
import '../../chart/domain/chart_note.dart';
import '../../gym/data/gym_repository.dart';
import '../../journal/domain/process_grade.dart';
import '../../journal/domain/trade.dart';
import '../../onboarding/domain/sessions.dart';

/// A bucket under this many trades is marked a small sample.
const int kSmallBucket = 5;

/// A trade opened this soon after a losing close (same day) is "after a loss".
const Duration kAfterLossWindow = Duration(minutes: 60);

/// Backtest and live each need this many trades before a gap is given.
const int kGapMinTrades = 10;

/// Grade counts are kept for this many weeks.
const int kGradeWeeks = 8;

/// A group of trades and what they add up to. Every figure is counted here,
/// never by the model.
class Bucket {
  const Bucket({
    required this.key,
    required this.count,
    required this.withRisk,
    required this.rTotal,
    required this.reviewed,
    required this.brokePlan,
    this.keptPlan = 0,
  });

  factory Bucket.of(String key, Iterable<Trade> trades) {
    var count = 0, withRisk = 0, reviewed = 0, broke = 0, kept = 0;
    var r = 0.0;
    for (final t in trades) {
      count++;
      if (t.r case final x?) {
        withRisk++;
        r += x;
      }
      if (t.grade case final g?) {
        reviewed++;
        if (g.brokePlan) broke++;
        if (g.keptPlan) kept++;
      }
    }
    return Bucket(
      key: key,
      count: count,
      withRisk: withRisk,
      rTotal: r,
      reviewed: reviewed,
      brokePlan: broke,
      keptPlan: kept,
    );
  }

  final String key;
  final int count;

  /// Trades with a known risk: only these count in R.
  final int withRisk;
  final double rTotal;
  final int reviewed;

  /// Reviewed trades graded D or F.
  final int brokePlan;

  /// Reviewed trades graded A or B.
  final int keptPlan;

  double? get averageR => withRisk == 0 ? null : rTotal / withRisk;

  /// % of reviewed trades graded D or F.
  double? get brokeShare => reviewed == 0 ? null : brokePlan / reviewed * 100;
  bool get smallSample => count < kSmallBucket;
}

/// A mistake tag and how often reviews used it.
class TagCount {
  const TagCount(this.tag, this.count, this.sharePct);

  final String tag;
  final int count;

  /// % of reviewed trades carrying the tag.
  final double sharePct;
}

/// A day with more trades than the account's max.
class MaxTradesBreak {
  const MaxTradesBreak({required this.day, required this.count, required this.max, required this.extraAt});

  /// Local date.
  final DateTime day;
  final int count;
  final int max;

  /// Local time the first trade over the max was opened.
  final DateTime extraAt;
}

/// One ISO week's grades (local Monday).
class WeekGrades {
  const WeekGrades(this.weekStart, this.counts);

  final DateTime weekStart;

  /// Letter → count, A to F; letters with none are 0.
  final Map<String, int> counts;
}

/// Backtest average R against live trades on the same instruments and dates.
class BacktestGap {
  const BacktestGap({required this.backtest, required this.live});

  final Bucket backtest;
  final Bucket live;

  bool get smallSample => backtest.withRisk < kGapMinTrades || live.withRisk < kGapMinTrades;

  /// Live minus backtest average R; null on a small sample.
  double? get gapR {
    if (smallSample) return null;
    return live.averageR! - backtest.averageR!;
  }
}

/// Practice over the last 28 days.
class GymFacts {
  const GymFacts({
    required this.drills,
    required this.correct,
    required this.replayGrades,
    required this.streak,
  });

  final int drills;
  final int correct;

  /// Grade letters of finished replay practices, oldest first.
  final List<String> replayGrades;
  final int streak;

  double? get correctPct => drills == 0 ? null : correct / drills * 100;
}

/// Everything the analyst may talk about, worked out on the device.
/// The model (later) and the fake analyst only explain these numbers.
class AnalystFacts {
  const AnalystFacts({
    required this.trades,
    required this.all,
    required this.breaksByTag,
    required this.afterLoss,
    required this.otherTrades,
    required this.byHour,
    required this.bySession,
    required this.byInstrument,
    required this.gradeTrend,
    required this.maxTradesBreaks,
    required this.notesMatching,
    required this.notesNotMatching,
    required this.backtestGap,
    required this.gym,
    required this.payout,
    required this.maxTrades,
  });

  /// [trades]: one account's trades. [sessions]: the trader's own sessions.
  /// [strategyWords]: the account's strategy plus the trader's sources, for
  /// matching chart-note reasons. [now] bounds the grade weeks and the gym.
  factory AnalystFacts.from({
    required List<Trade> trades,
    List<ChartNote> notes = const [],
    List<BacktestSession> backtests = const [],
    List<GymEntry> gym = const [],
    List<TradingSession> sessions = const [],
    String strategyWords = '',
    int? maxTrades,
    int streak = 0,
    List<RuleDistance> payout = const [],
    required DateTime now,
  }) {
    final sorted = [...trades]..sort((a, b) => a.openedAt.compareTo(b.openedAt));
    final reviewed = sorted.where((t) => t.reviewed).toList();

    final tags = [
      for (final tag in kMistakeTags)
        if (reviewed.where((t) => t.mistakes.contains(tag)).length case final n when n > 0)
          TagCount(tag, n, n / reviewed.length * 100),
    ]..sort((a, b) => b.count.compareTo(a.count));

    final after = sorted.where((t) => isAfterLoss(t, sorted)).toSet();

    final notesByTrade = <String, bool>{};
    final byId = {for (final t in sorted) t.id: t};
    for (final n in notes) {
      final reason = n.reason?.trim() ?? '';
      final id = n.tradeId;
      if (n.deleted || reason.isEmpty || id == null || !byId.containsKey(id)) continue;
      final match = FakeCopilot.ruleMatching(strategyWords, reason) != null;
      notesByTrade[id] = (notesByTrade[id] ?? false) || match;
    }

    return AnalystFacts(
      trades: sorted.length,
      all: Bucket.of('all trades', sorted),
      breaksByTag: tags,
      afterLoss: Bucket.of('after a loss', after),
      otherTrades: Bucket.of('other trades', sorted.where((t) => !after.contains(t))),
      byHour: _group(sorted, (t) => '${t.openedAt.toLocal().hour.toString().padLeft(2, '0')}:00'),
      bySession: _group(sorted, (t) => sessionOf(t.openedAt, sessions)),
      byInstrument: _group(sorted, (t) => t.symbol),
      gradeTrend: gradeWeeks(reviewed, now),
      maxTradesBreaks: maxTrades == null ? const [] : maxTradesBreaksOf(sorted, maxTrades),
      notesMatching: Bucket.of('reason in your written rules', [
        for (final e in notesByTrade.entries)
          if (e.value) byId[e.key]!,
      ]),
      notesNotMatching: Bucket.of('reason not in your written rules', [
        for (final e in notesByTrade.entries)
          if (!e.value) byId[e.key]!,
      ]),
      backtestGap: backtestGapOf(backtests, sorted),
      gym: gymFactsOf(gym, now, streak),
      payout: payout,
      maxTrades: maxTrades,
    );
  }

  final int trades;
  final Bucket all;

  /// Most used first; tags never used are left out.
  final List<TagCount> breaksByTag;
  final Bucket afterLoss;
  final Bucket otherTrades;

  /// Local open hour, "09:00", in hour order.
  final List<Bucket> byHour;

  /// Session label, or "outside your sessions".
  final List<Bucket> bySession;
  final List<Bucket> byInstrument;

  /// Oldest week first, [kGradeWeeks] of them.
  final List<WeekGrades> gradeTrend;
  final List<MaxTradesBreak> maxTradesBreaks;

  /// Trades whose chart-note reason matched a sentence of the trader's rules.
  final Bucket notesMatching;
  final Bucket notesNotMatching;

  /// Null when there is no automatic backtest on this account.
  final BacktestGap? backtestGap;
  final GymFacts gym;
  final List<RuleDistance> payout;
  final int? maxTrades;

  // TODO(backend): toJson for ai-analyst (design/analyst-plan.md › request).
}

/// Opened within [kAfterLossWindow] after a losing trade closed, same local day.
bool isAfterLoss(Trade t, List<Trade> all) {
  final open = t.openedAt;
  final day = open.toLocal();
  return all.any((p) {
    if (identical(p, t) || !p.isLoss || p.closedAt.isAfter(open)) return false;
    final c = p.closedAt.toLocal();
    return c.year == day.year &&
        c.month == day.month &&
        c.day == day.day &&
        open.difference(p.closedAt) <= kAfterLossWindow;
  });
}

/// The first of the trader's sessions open at [at], else "outside your sessions".
String sessionOf(DateTime at, List<TradingSession> sessions) =>
    sessions.where((s) => s.isOpenAt(at)).firstOrNull?.label ?? 'outside your sessions';

List<Bucket> _group(List<Trade> trades, String Function(Trade) keyOf) {
  final groups = <String, List<Trade>>{};
  for (final t in trades) {
    groups.putIfAbsent(keyOf(t), () => []).add(t);
  }
  final keys = groups.keys.toList()..sort();
  return [for (final k in keys) Bucket.of(k, groups[k]!)];
}

DateTime _monday(DateTime local) {
  final d = DateTime(local.year, local.month, local.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Grade counts for the [kGradeWeeks] weeks up to [now]'s, by close date.
List<WeekGrades> gradeWeeks(List<Trade> reviewed, DateTime now) {
  final thisWeek = _monday(now.toLocal());
  return [
    for (var i = kGradeWeeks - 1; i >= 0; i--)
      () {
        final start = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i);
        final counts = {for (final g in ProcessGrade.values) g.letter: 0};
        for (final t in reviewed) {
          if (_monday(t.closedAt.toLocal()) == start) counts[t.grade!.letter] = counts[t.grade!.letter]! + 1;
        }
        return WeekGrades(start, counts);
      }(),
  ];
}

/// Days with more trades than [max] ([sorted] by open time).
List<MaxTradesBreak> maxTradesBreaksOf(List<Trade> sorted, int max) {
  final byDay = <DateTime, List<Trade>>{};
  for (final t in sorted) {
    final l = t.openedAt.toLocal();
    byDay.putIfAbsent(DateTime(l.year, l.month, l.day), () => []).add(t);
  }
  return [
    for (final e in byDay.entries)
      if (e.value.length > max)
        MaxTradesBreak(day: e.key, count: e.value.length, max: max, extraAt: e.value[max].openedAt.toLocal()),
  ];
}

/// The newest automatic backtest against live trades on its instruments
/// opened inside its dates.
BacktestGap? backtestGapOf(List<BacktestSession> sessions, List<Trade> live) {
  final auto = sessions.where((s) => s.kind == BacktestKind.auto).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final s = auto.firstOrNull;
  if (s == null) return null;
  var count = 0;
  var r = 0.0;
  for (final t in s.trades.where((t) => t.closed)) {
    count++;
    r += t.r;
  }
  final backtest = Bucket(
    key: 'backtest',
    count: count,
    withRisk: count,
    rTotal: r,
    reviewed: 0,
    brokePlan: 0,
  );
  final inside = live.where(
    (t) => s.symbols.contains(t.symbol) && !t.openedAt.isBefore(s.from) && !t.openedAt.isAfter(s.to),
  );
  return BacktestGap(backtest: backtest, live: Bucket.of('live', inside));
}

/// Drill answers and replay grades from the 28 days before [now].
GymFacts gymFactsOf(List<GymEntry> entries, DateTime now, int streak) {
  final since = now.subtract(const Duration(days: 28));
  final recent = entries.where((e) => e.at.isAfter(since)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final drills = recent.where((e) => e.kind == GymEntryKind.drill && e.correct != null);
  return GymFacts(
    drills: drills.length,
    correct: drills.where((e) => e.correct!).length,
    replayGrades: [for (final e in recent) ?e.grade],
    streak: streak,
  );
}
