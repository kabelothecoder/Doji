import '../../../core/widgets/grid_cell.dart';
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
  const MeBadge(this.id, this.glyph, this.title, this.line, {required this.earned});

  final String id;
  final String glyph;
  final String title;
  final String line;
  final bool earned;
}

/// The badge list. [earned] is the stored set (badges stay earned once
/// reached); the locked lines count from the current data.
List<MeBadge> badgesFor(List<Trade> trades, Set<DateTime> practiceDays, Set<String> earned) {
  final best = bestKeptStreak(keptDays(trades));
  final p = practiceDays.length;
  bool e(String id) => earned.contains(id);
  return [
    // TODO(backend): the founding number comes from the account once accounts sync.
    const MeBadge('founding', '#', 'founding', 'locked · given when accounts go live', earned: false),
    MeBadge(
      'streak7',
      '7',
      '7-day streak',
      e('streak7') ? '7 days kept in a row' : 'locked · $best of 7 days',
      earned: e('streak7'),
    ),
    MeBadge(
      'streak30',
      '30',
      '30-day streak',
      e('streak30') ? '30 days kept in a row' : 'locked · $best of 30 days',
      earned: e('streak30'),
    ),
    MeBadge(
      'cleanWeek',
      'clean',
      'first clean week',
      e('cleanWeek') ? 'a week with no rule breaks' : 'locked · a week with no rule breaks',
      earned: e('cleanWeek'),
    ),
    MeBadge(
      'firstPractice',
      'gym',
      'first practice day',
      e('firstPractice') ? 'a full drill set done' : 'locked · finish a drill set',
      earned: e('firstPractice'),
    ),
    MeBadge(
      'practice10',
      '10',
      '10 practice days',
      e('practice10') ? '10 days of drills' : 'locked · ${p.clamp(0, 10)} of 10 days',
      earned: e('practice10'),
    ),
  ];
}

/// One grid cell for [day]: kept = L4, a day that broke the plan = L1, no
/// reviewed trades = L0, after [today] = future. Home's MiniGrid and the year
/// grid both use it, so the two always agree.
GridCellState dayCell(DateTime day, Map<DateTime, bool> kept, DateTime today) {
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  if (d.isAfter(t)) return GridCellState.future;
  return switch (kept[d]) {
    true => GridCellState.l4,
    false => GridCellState.l1,
    null => d == t ? GridCellState.today : GridCellState.l0,
  };
}

/// Badge ids earned from today's data: journal kept days plus gym drill days.
/// Founding is never earned on the device.
Set<String> earnedBadgeIds(List<Trade> trades, Set<DateTime> practiceDays) {
  final days = keptDays(trades);
  final best = bestKeptStreak(days);
  return {
    if (best >= 7) 'streak7',
    if (best >= 30) 'streak30',
    if (hasCleanWeek(days)) 'cleanWeek',
    if (practiceDays.isNotEmpty) 'firstPractice',
    if (practiceDays.length >= 10) 'practice10',
  };
}
