import '../../../core/copy_rules.dart';
import '../../accounts/domain/payout_readiness.dart';
import '../../chart/domain/copilot.dart';
import '../../coach/data/fake_coach.dart';
import '../../coach/domain/coach.dart';
import '../../markets/domain/pair_brief.dart';
import '../domain/aggregates.dart';
import '../domain/analyst.dart';

/// Said when a line would break the copy rules, and when nothing matched.
const kAnalystFallback =
    'which part do you want to look at: max trades, trades after a loss, time of day, '
    'session, instrument, grades, practice or payout rules?';

/// Said when asked where price goes.
const kAnalystNoCalls =
    "i only read your own trades. where price goes isn't something doji says. "
    'want to look at when you break your rules instead?';

/// Written on the device from [AnalystFacts] only. Local runs and tests use
/// it. TODO(backend): SupabaseAnalyst → `ai-analyst` (design/analyst-plan.md),
/// falling back to this on any failure, like the other AI clients.
class FakeAnalyst implements Analyst {
  const FakeAnalyst({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  @override
  Future<WeeklyReview> weeklyReview({
    required String accountId,
    required DateTime weekStart,
    required AnalystFacts week,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return reviewFor(accountId: accountId, weekStart: weekStart, week: week);
  }

  static WeeklyReview reviewFor({
    required String accountId,
    required DateTime weekStart,
    required AnalystFacts week,
  }) {
    final all = week.all;
    final max = week.maxTrades;
    final kept = [
      if (all.count == 0)
        'no trades this week.'
      else if (all.reviewed == 0)
        '${_trades(all.count)} this week, none reviewed yet, so there are no grades to read.'
      else
        '${all.keptPlan} of ${all.reviewed} reviewed trades kept your plan (graded A or B).',
      if (max != null && all.count > 0 && week.maxTradesBreaks.isEmpty)
        'you stayed within $max trades every day.',
    ].join(' ');
    final top = week.breaksByTag.firstOrNull;
    final days = week.maxTradesBreaks.length;
    final broke = [
      if (top != null) '"${top.tag}" came up on ${top.count} of ${all.reviewed} reviewed trades.',
      if (days > 0) '$days ${days == 1 ? 'day' : 'days'} went past $max trades.',
      if (top == null && days == 0) 'no broken rules were tagged this week.',
    ].join(' ');
    return WeeklyReview(
      accountId: accountId,
      weekStart: weekStart,
      kept: _safe(kept, 'your grades for the week are in the journal.'),
      broke: _safe(broke, 'your tags for the week are in the journal.'),
      focusRule: focusRuleFor(week),
    );
  }

  @override
  Future<String> reply(AnalystFacts facts, List<BriefTurn> history, String message) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return replyFor(facts, message);
  }

  static String replyFor(AnalystFacts f, String message) {
    final m = message.toLowerCase();
    if (FakeCoach.intentOf(message) == CoachIntent.crisis) {
      return FakeCoach.replyFor(CoachIntent.crisis, const CoachContext());
    }
    bool has(List<String> words) => words.any(m.contains);
    final String line;
    if (has([
      'will ',
      'go up',
      'go down',
      'price',
      'direction',
      'forecast',
      'predict',
      'next move',
      'target',
    ])) {
      line = kAnalystNoCalls;
    } else if (has(['max trade', 'overtrad', 'too many'])) {
      line = _maxTrades(f);
    } else if (has(['revenge', 'after a loss', 'after loss', 'losing', 'loss'])) {
      line = _afterLoss(f);
    } else if (has(['session', 'london', 'new york', 'tokyo', 'sydney'])) {
      line = _worst(f.bySession, 'by session');
    } else if (has(['time', 'hour', 'when', 'morning', 'afternoon'])) {
      line = _worst(f.byHour, 'by the hour you opened');
    } else if (has(['instrument', 'pair', 'symbol', 'market'])) {
      line = _worst(f.byInstrument, 'by instrument');
    } else if (has(['grade', 'improv', 'trend', 'better', 'worse'])) {
      line = _grades(f);
    } else if (has(['payout', 'consisten', 'drawdown', 'trading day', 'prop'])) {
      line = _payout(f);
    } else if (has(['backtest', 'live'])) {
      line = _gap(f);
    } else if (has(['gym', 'drill', 'practice', 'replay'])) {
      line = _gym(f);
    } else if (has(['note', 'reason', 'chart'])) {
      line = _notes(f);
    } else if (has(['tag', 'mistake', 'break', 'broke'])) {
      line = _tags(f);
    } else {
      line = kAnalystFallback;
    }
    return _safe(line, kAnalystFallback);
  }

  static String _maxTrades(AnalystFacts f) {
    final max = f.maxTrades;
    if (max == null) return 'this account has no max trades a day set.';
    final b = f.maxTradesBreaks;
    if (b.isEmpty) return 'you have not gone past $max trades on any day so far.';
    final hours = <int, int>{};
    final weekdays = <int, int>{};
    for (final x in b) {
      hours.update(x.extraAt.hour, (n) => n + 1, ifAbsent: () => 1);
      weekdays.update(x.day.weekday, (n) => n + 1, ifAbsent: () => 1);
    }
    final hour = _mostCommon(hours);
    final day = _mostCommon(weekdays);
    return 'you went past $max trades on ${b.length} ${b.length == 1 ? 'day' : 'days'}. '
        'the extra trade most often opened around ${hour.toString().padLeft(2, '0')}:00, '
        'and most often on a ${_weekday(day)}. what is usually going on at that time?';
  }

  static String _afterLoss(AnalystFacts f) {
    final a = f.afterLoss, o = f.otherTrades;
    if (a.count == 0) return 'none of your trades opened within an hour of a loss.';
    final note = a.smallSample ? ' small sample, so read it loosely.' : '';
    final aShare = a.brokeShare, oShare = o.brokeShare;
    final grades = aShare == null || oShare == null
        ? ''
        : ' ${fmtNum(aShare)}% of the reviewed ones broke your plan, against ${fmtNum(oShare)}% of the rest.';
    return '${_trades(a.count)} opened within an hour of a loss.$grades$note '
        'what do you notice in yourself right after a loss?';
  }

  /// The bucket with the most plan breaks among those reviewed.
  static String _worst(List<Bucket> buckets, String how) {
    final reviewed = buckets.where((b) => b.reviewed > 0).toList()
      ..sort((a, b) => b.brokeShare!.compareTo(a.brokeShare!));
    final w = reviewed.firstOrNull;
    if (w == null) return 'no reviewed trades yet to compare $how.';
    final note = w.smallSample ? ' small sample, so read it loosely.' : '';
    return '$how, ${w.key} has the most plan breaks: ${w.brokePlan} of ${w.reviewed} reviewed.$note '
        'what is different for you there?';
  }

  static String _grades(AnalystFacts f) {
    final weeks = f.gradeTrend.where((w) => w.counts.values.any((n) => n > 0)).toList();
    if (weeks.isEmpty) return 'no reviewed trades in the last $kGradeWeeks weeks.';
    String kept(WeekGrades w) =>
        '${w.counts['A']! + w.counts['B']!} of ${w.counts.values.fold(0, (s, n) => s + n)}';
    final first = weeks.first, last = weeks.last;
    if (identical(first, last)) return 'one reviewed week so far: ${kept(last)} kept your plan.';
    return 'your first reviewed week here: ${kept(first)} kept your plan. the latest: ${kept(last)}. '
        'what changed between them?';
  }

  static String _payout(AnalystFacts f) {
    if (f.payout.isEmpty) return 'payout rules are for prop accounts. this one has none set.';
    return [for (final r in f.payout) '${r.line} (${r.standing.label}).'].join(' ');
  }

  static String _gap(AnalystFacts f) {
    final g = f.backtestGap;
    if (g == null) return 'there is no backtest on this account yet.';
    final gap = g.gapR;
    if (gap == null) {
      return 'small sample: ${g.backtest.withRisk} backtest and ${g.live.withRisk} live trades. '
          'doji compares them from $kGapMinTrades each.';
    }
    return 'live trades averaged ${_r(g.live.averageR!)} against ${_r(g.backtest.averageR!)} in the backtest, '
        'a gap of ${_r(gap)}. the backtest has no costs or spread. what do you do live that it does not?';
  }

  static String _gym(AnalystFacts f) {
    final g = f.gym;
    final pct = g.correctPct;
    final drills = pct == null
        ? 'no drills in the last 28 days.'
        : '${g.correct} of ${g.drills} drill answers right in the last 28 days.';
    final replays = g.replayGrades.isEmpty ? '' : ' replay practice grades: ${g.replayGrades.join(', ')}.';
    return '$drills$replays drill streak: ${g.streak}.';
  }

  static String _notes(AnalystFacts f) {
    final a = f.notesMatching, b = f.notesNotMatching;
    if (a.count + b.count == 0) return 'no chart notes with a reason are linked to your trades yet.';
    String avg(Bucket x) => x.averageR == null ? 'no R yet' : 'average ${_r(x.averageR!)}';
    return '${_trades(a.count)} had a chart reason that matches your written rules (${avg(a)}); '
        '${_trades(b.count)} had one that does not (${avg(b)}). which rule were those others following?';
  }

  static String _tags(AnalystFacts f) {
    if (f.breaksByTag.isEmpty) return 'no mistake tags in your reviews yet.';
    final top = f.breaksByTag.take(3).map((t) => '"${t.tag}" ${t.count}').join(', ');
    return 'most used mistake tags: $top. which one costs you the most calm?';
  }

  static int _mostCommon(Map<int, int> counts) =>
      counts.entries.reduce((a, b) => b.value > a.value || (b.value == a.value && b.key < a.key) ? b : a).key;

  static String _weekday(int d) =>
      const ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'][d - 1];

  static String _trades(int n) => '$n ${n == 1 ? 'trade' : 'trades'}';

  static String _r(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}R';

  /// Every line goes through the copy rules and the odds words.
  static String _safe(String line, String fallback) =>
      breaksCopyRules(line) || ratesOdds(line) ? fallback : line;
}
