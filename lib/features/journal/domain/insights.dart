import 'process_grade.dart';
import 'trade.dart';

/// Leak = a pattern that costs R; edge = one that adds it. Shown as words, never colour alone.
enum InsightKind { leak, edge }

/// Below this many trades in a pattern, an insight is not shown at all.
const int kInsightMinTrades = 3;

/// Below this many, it is shown as a small sample.
const int kInsightSolidTrades = 10;

/// Entries opened from this local hour count as "late" for the time insight.
const int kLateEntryHour = 15;

/// One pattern found in the trader's own closed trades (design: Doji Insight Card, Doji Trade
/// Journal Phone › insights). Measured in R only: never money, never a hit rate.
class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.type,
    required this.headline,
    required this.trades,
    required this.others,
    required this.how,
    required this.rule,
  });

  /// Stable for the pattern ("time", "tag:revenge"), so watching and hiding survive a recompute.
  final String id;
  final InsightKind kind;

  /// The family a "not useful" hides ("time", "setup", "tag"…).
  final String type;
  final String headline;

  /// The trades in the pattern, oldest first, each with an R.
  final List<Trade> trades;

  /// How many other trades it was compared with.
  final int others;
  final List<String> how;

  /// The rule the trader can add to their plan, in their voice.
  final String rule;

  int get n => trades.length;
  double get totalR => trades.fold(0.0, (s, t) => s + t.r!);
  double get perTradeR => totalR / n;
  bool get smallSample => n < kInsightSolidTrades;
  String? get note => smallSample ? 'only $n trades · small sample' : null;
}

/// "+1.5R" / "−2R" (one decimal at most, a real minus sign).
String rText(double r) {
  final v = (r * 10).roundToDouble() / 10;
  final s = v.abs() == v.abs().roundToDouble() ? v.abs().toInt().toString() : v.abs().toStringAsFixed(1);
  return '${v < 0 ? '−' : '+'}${s}R';
}

String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

int _weeks(List<Trade> ts) {
  final weeks = <int>{};
  for (final t in ts) {
    final l = t.openedAt.toLocal();
    weeks.add(
      DateTime(l.year, l.month, l.day).subtract(Duration(days: l.weekday - 1)).millisecondsSinceEpoch,
    );
  }
  return weeks.length;
}

/// The insights in [trades] (one account's), leaks first then edges, biggest R first in each.
/// Only trades with an R count; a pattern needs [kInsightMinTrades] of them.
List<Insight> findInsights(Iterable<Trade> trades) {
  final withR = [
    for (final t in trades)
      if (t.r != null) t,
  ]..sort((a, b) => a.openedAt.compareTo(b.openedAt));
  final total = withR.length;
  final out = <Insight?>[];

  Insight? make({
    required String id,
    required String type,
    required List<Trade> group,
    required InsightKind? Function(double total, double rest) kindOf,
    required String Function(Insight draft) headline,
    required String found,
    required String rule,
  }) {
    if (group.length < kInsightMinTrades) return null;
    final rest = withR.where((t) => !group.contains(t)).toList();
    final restAvg = rest.isEmpty ? 0.0 : rest.fold(0.0, (s, t) => s + t.r!) / rest.length;
    final sum = group.fold(0.0, (s, t) => s + t.r!);
    final kind = kindOf(sum, restAvg);
    if (kind == null) return null;
    final draft = Insight(
      id: id,
      kind: kind,
      type: type,
      headline: '',
      trades: group,
      others: rest.length,
      how: [
        'found in ${group.length} of your $total trades ($found).',
        if (rest.isNotEmpty) 'the other ${rest.length} average ${rText(restAvg)} a trade.',
        'spread over ${_weeks(group)} ${_weeks(group) == 1 ? 'week' : 'weeks'}.',
      ],
      rule: rule,
    );
    return Insight(
      id: id,
      kind: kind,
      type: type,
      headline: headline(draft),
      trades: group,
      others: rest.length,
      how: draft.how,
      rule: rule,
    );
  }

  InsightKind? leakIfWorse(double sum, double restAvg) => sum < 0 ? InsightKind.leak : null;

  // Time of day: entries from 15:00 local.
  final late = [
    for (final t in withR)
      if (t.openedAt.toLocal().hour >= kLateEntryHour) t,
  ];
  out.add(
    make(
      id: 'time',
      type: 'time',
      group: late,
      kindOf: leakIfWorse,
      headline: (i) => 'your trades opened from ${_hh(kLateEntryHour)} total ${rText(i.totalR)}',
      found: 'opened from ${_hh(kLateEntryHour)}',
      rule: 'no new entries from ${_hh(kLateEntryHour)}',
    ),
  );

  // Setups: the best named one is an edge.
  final setups = <String, List<Trade>>{};
  for (final t in withR) {
    if (t.setup case final s? when s != kNoSetup) (setups[s] ??= []).add(t);
  }
  final best = setups.entries.where((e) => e.value.length >= kInsightMinTrades).toList()
    ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));
  if (best.isNotEmpty) {
    final s = best.first.key;
    out.add(
      make(
        id: 'setup:$s',
        type: 'setup',
        group: best.first.value,
        kindOf: (sum, _) => sum > 0 ? InsightKind.edge : null,
        headline: (i) => '$s: ${rText(i.totalR)} over ${i.n} trades, your strongest setup so far',
        found: 'setup: $s',
        rule: '$s is my main setup: full size only there',
      ),
    );
  }

  // Sequence: trades opened after two losing closes in a row, the same local day.
  final afterTwo = <Trade>[];
  for (var i = 2; i < withR.length; i++) {
    final a = withR[i - 2], b = withR[i - 1], t = withR[i];
    final d = t.openedAt.toLocal();
    bool sameDay(Trade x) {
      final c = x.closedAt.toLocal();
      return c.year == d.year && c.month == d.month && c.day == d.day;
    }

    if (a.isLoss && b.isLoss && sameDay(a) && sameDay(b) && !b.closedAt.isAfter(t.openedAt)) afterTwo.add(t);
  }
  out.add(
    make(
      id: 'sequence',
      type: 'sequence',
      group: afterTwo,
      kindOf: leakIfWorse,
      headline: (i) => 'trades taken after 2 losses in a row total ${rText(i.totalR)} over ${i.n} trades',
      found: 'after 2 losses in a row',
      rule: 'stop for the day after 2 losses in a row',
    ),
  );

  // Plan kept vs broken: an edge when keeping the plan averages more.
  final kept = [
    for (final t in withR)
      if (t.grade?.keptPlan ?? false) t,
  ];
  final broke = [
    for (final t in withR)
      if (t.grade?.brokePlan ?? false) t,
  ];
  if (kept.length >= kInsightMinTrades && broke.length >= kInsightMinTrades) {
    final k = _sum(kept) / kept.length, b = _sum(broke) / broke.length;
    if (k > b) {
      out.add(
        Insight(
          id: 'rule',
          kind: InsightKind.edge,
          type: 'rule',
          headline: 'graded A–B: ${rText(k)} a trade. graded D–F: ${rText(b)} a trade',
          trades: kept,
          others: broke.length,
          how: [
            'compared ${kept.length} trades graded A or B with ${broke.length} graded D or F.',
            'grades come from your own reviews, not from the result.',
            'spread over ${_weeks(kept)} ${_weeks(kept) == 1 ? 'week' : 'weeks'}.',
          ],
          rule: 'if a rule breaks, the trade closes',
        ),
      );
    }
  }

  // Instruments: the one that costs the most.
  final pairs = <String, List<Trade>>{};
  for (final t in withR) {
    (pairs[t.symbol] ??= []).add(t);
  }
  final worst = pairs.entries.where((e) => e.value.length >= kInsightMinTrades && _sum(e.value) < 0).toList()
    ..sort((a, b) => _sum(a.value).compareTo(_sum(b.value)));
  if (worst.isNotEmpty && pairs.length > 1) {
    final s = worst.first.key;
    out.add(
      make(
        id: 'pair:$s',
        type: 'pair',
        group: worst.first.value,
        kindOf: leakIfWorse,
        headline: (i) => '$s: ${rText(i.totalR)} over ${i.n} trades',
        found: 'instrument: $s',
        rule: 'no trades on $s for now',
      ),
    );
  }

  // Mistake tags.
  const tagLines = {
    'moved stop': 'the stop only moves to reduce risk',
    'early exit': 'no manual close before 1R',
    'late entry': 'if the trigger is gone, so is the trade',
    'oversized': 'size comes from the stop, not the feeling',
    'revenge': 'after a loss, wait 15 min before the next entry',
    'FOMO': 'no setup, no trade',
    'against plan': 'if it is not in the plan, i skip it',
    'news spike': 'no entries inside the news window',
    'overtrading': 'stop at my max trades',
  };
  for (final e in tagLines.entries) {
    out.add(
      make(
        id: 'tag:${e.key}',
        type: 'tag',
        group: [
          for (final t in withR)
            if (t.mistakes.contains(e.key)) t,
        ],
        kindOf: leakIfWorse,
        headline: (i) => 'trades tagged "${e.key}" total ${rText(i.totalR)} over ${i.n} trades',
        found: 'tag: ${e.key}',
        rule: e.value,
      ),
    );
  }

  // Emotion before the entry, 7 or more.
  for (final name in kJournalEmotions) {
    out.add(
      make(
        id: 'emotion:$name',
        type: 'emotion',
        group: [
          for (final t in withR)
            if (t.before case final b? when b.name == name && b.intensity >= 7) t,
        ],
        kindOf: leakIfWorse,
        headline: (i) => 'trades entered feeling $name 7+ average ${rText(i.perTradeR)}',
        found: 'before: $name 7+',
        rule: 'no entries when $name is 7 or higher',
      ),
    );
  }

  // Wins with no setup: the result paid for a mistake.
  out.add(
    make(
      id: 'lucky',
      type: 'no setup',
      group: [
        for (final t in withR)
          if (t.isWin && (t.setup == kNoSetup || t.mistakes.contains(kNoSetup))) t,
      ],
      kindOf: (sum, _) => InsightKind.leak,
      headline: (i) => '${i.n} winning trades had no setup from your strategy',
      found: 'wins with no setup',
      rule: 'only trade setups from my strategy',
    ),
  );

  final found = out.whereType<Insight>().toList();
  return [
    ...found.where((i) => i.kind == InsightKind.leak).toList()..sort((a, b) => a.totalR.compareTo(b.totalR)),
    ...found.where((i) => i.kind == InsightKind.edge).toList()..sort((a, b) => b.totalR.compareTo(a.totalR)),
  ];
}

double _sum(List<Trade> ts) => ts.fold(0.0, (s, t) => s + t.r!);
