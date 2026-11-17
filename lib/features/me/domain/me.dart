import '../../journal/domain/trade.dart';

/// The rank ladder (Doji Me Phone › RANK LADDER), lowest first.
const kRanks = <(String code, String name)>[
  ('M1', 'impulsive'),
  ('M5', 'aware'),
  ('M15', 'learning'),
  ('H1', 'steady'),
  ('H4', 'disciplined'),
  ('D1', 'consistent'),
  ('W1', 'composed'),
  ('MN', 'doji'),
];

DateTime _day(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Local dates with a closed trade, each marked kept (every reviewed trade
/// graded A or B, at least one reviewed) or not. Unreviewed days are left out.
Map<DateTime, bool> keptDays(List<Trade> trades) {
  final out = <DateTime, bool>{};
  for (final t in trades) {
    final g = t.grade;
    if (g == null) continue;
    final d = _day(t.closedAt);
    out[d] = (out[d] ?? true) && g.keptPlan;
  }
  return out;
}

/// Kept trading days in a row, counting back from the newest reviewed day.
/// Days without trades don't break it; a day that broke the plan does.
int keptStreak(Map<DateTime, bool> days) {
  final dates = days.keys.toList()..sort((a, b) => b.compareTo(a));
  var n = 0;
  for (final d in dates) {
    if (!days[d]!) break;
    n++;
  }
  return n;
}

/// The longest kept run ever (for the streak badges, which stay earned).
int bestKeptStreak(Map<DateTime, bool> days) {
  final dates = days.keys.toList()..sort();
  var best = 0, run = 0;
  for (final d in dates) {
    run = days[d]! ? run + 1 : 0;
    if (run > best) best = run;
  }
  return best;
}

/// A Monday-start week with reviewed trades and none broke the plan.
bool hasCleanWeek(Map<DateTime, bool> days) {
  final weeks = <DateTime, bool>{};
  days.forEach((d, kept) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    weeks[monday] = (weeks[monday] ?? true) && kept;
  });
  return weeks.values.any((v) => v);
}

class MeBadge {
  const MeBadge(this.glyph, this.title, this.line, {required this.earned});

  final String glyph;
  final String title;
  final String line;
  final bool earned;
}

List<MeBadge> badgesFor(List<Trade> trades) {
  final days = keptDays(trades);
  final best = bestKeptStreak(days);
  return [
    // TODO(backend): the founding number comes from the account once accounts sync.
    const MeBadge('#', 'founding', 'locked · given when accounts go live', earned: false),
    MeBadge(
      '7',
      '7-day streak',
      best >= 7 ? '7 days kept in a row' : 'locked · $best of 7 days',
      earned: best >= 7,
    ),
    MeBadge(
      '30',
      '30-day streak',
      best >= 30 ? '30 days kept in a row' : 'locked · $best of 30 days',
      earned: best >= 30,
    ),
    MeBadge(
      'clean',
      'first clean week',
      hasCleanWeek(days) ? 'a week with no rule breaks' : 'locked · a week with no rule breaks',
      earned: hasCleanWeek(days),
    ),
  ];
}
