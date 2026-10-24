import '../../../core/widgets/grid_cell.dart';
import '../../journal/domain/journal_stats.dart';
import '../../journal/domain/trade.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/prop_drawdown.dart';
import '../../onboarding/domain/sessions.dart';
import '../../onboarding/domain/user_zone.dart';

/// Home's day-zero tasks (Doji Home Phone: ITEMS).
enum SetupTask {
  brief('run your first ai brief', 'about 20 seconds'),
  coach('try the coach for 30 seconds', 'voice or text'),
  connect('connect your account', 'optional · read-only');

  const SetupTask(this.title, this.sub);
  final String title;
  final String sub;
}

/// Moods on The Open (Doji Home Phone: MOODS).
const List<String> openMoods = [
  'calm',
  'focused',
  'confident',
  'patient',
  'tired',
  'anxious',
  'restless',
  'frustrated',
];

/// Evening starts here; "close your day" is offered from this hour.
/// TODO(next-slice): make it a setting ("from [17:00]").
const int eveningFromHour = 17;

/// A rule counter: used vs limit, drawn by `RuleMeter`.
class RuleUsage {
  const RuleUsage({required this.label, required this.used, required this.limit, required this.unit});

  final String label;
  final num used;
  final num limit;

  /// '' for counts, '%' for account percent.
  final String unit;
}

/// A brief condition: shape plus word, never colour alone.
class BriefCondition {
  const BriefCondition(this.text, {required this.met});
  final String text;
  final bool met;
}

/// The day, as the screens need it. Trades taken, loss, tilt and the prop
/// drawdown come from the journal; the score, streak, brief conditions and
/// news are still PLACEHOLDER until their own slices.
class HomeSnapshot {
  const HomeSnapshot({
    required this.name,
    required this.rank,
    required this.instruments,
    required this.rules,
    required this.usage,
    required this.conditions,
    required this.losses,
    required this.lossesToCooldown,
    required this.score,
    required this.streak,
  });

  final String name;
  final String rank;

  /// Instrument symbols, first = the one the brief and rail show.
  final List<String> instruments;
  final List<String> rules;
  final List<RuleUsage> usage;
  final List<BriefCondition> conditions;
  final int losses;
  final int lossesToCooldown;
  final int score;
  final int? streak;

  /// Shown after two losses in a row.
  bool get tilt => losses >= 2;
  int get metCount => conditions.where((c) => c.met).length;

  /// Tilt meter, 1–5. TODO(next-slice): also from emotion logs.
  int get tiltLevel => (1 + losses * 2).clamp(1, 5);
  String get tiltWord => tiltLevel <= 2 ? 'low' : (tiltLevel <= 4 ? 'elevated' : 'high');

  /// [now] decides whether the first instrument's market is open and which
  /// trades count as today's.
  factory HomeSnapshot.fromJournal(ProfileDoji p, {required List<Trade> trades, DateTime? now}) {
    final rules = p.rules;
    final prop = p.prop;
    final day = DaySummary.of(trades, now ?? DateTime.now());
    // Only a prop challenge states the account size, so only it has a real
    // drawdown; without a size doji shows no meter instead of inventing one.
    final accountSize = prop?.accountSize?.toDouble();
    final lossPct = day.lossPercent(accountSize: accountSize, riskPerTradePct: rules?.riskPerTrade ?? 1.0);
    final maxTrades = rules?.maxTradesPerDay ?? 3;
    // The stricter of the user's own daily loss limit and the prop firm's.
    final limits = [rules?.dailyLossLimit, prop?.dailyLossLimitPct].whereType<double>();
    final lossLimit = limits.isEmpty ? 2.0 : limits.reduce((a, b) => a < b ? a : b);
    final instruments = p.instruments.isEmpty ? defaultInstruments : p.instruments;
    final first = instrumentBySymbol(instruments.first);
    // Unknown (custom) symbols: assume open rather than say a false "waiting".
    final marketOpen = first?.hours.isOpenAt(now ?? DateTime.now().toUtc()) ?? true;
    final drawdown = prop == null || accountSize == null
        ? null
        : PropDrawdown.evaluate(prop, accountSize: accountSize, state: accountStateFrom(trades, accountSize));
    return HomeSnapshot(
      name: p.name ?? 'trader',
      rank: p.rank,
      instruments: instruments,
      rules: [
        'max ${rules?.maxTradesPerDay ?? '[3]'} trades',
        'stop at ${_n(lossLimit)}% daily loss',
        if (drawdown != null) 'prop max drawdown ${_n(drawdown.limitPct)}% (${prop!.drawdownLabel})',
        'no entries 15 min around high-impact news',
        'only [setup name] setups',
      ],
      usage: [
        RuleUsage(label: 'trades', used: day.count, limit: maxTrades, unit: ''),
        RuleUsage(label: 'daily loss', used: _round2(lossPct), limit: lossLimit, unit: '%'),
        // The label and the amount follow the type the user chose.
        if (drawdown != null)
          RuleUsage(
            label: 'prop ${drawdown.label}',
            used: _round2(drawdown.usedPct),
            limit: drawdown.limitPct,
            unit: '%',
          ),
      ],
      // TODO(next-slice): conditions measured against the parsed strategy.
      conditions: [
        BriefCondition('${instrumentLabel(instruments.first)} market open', met: marketOpen),
        const BriefCondition('price at your key level', met: false),
        const BriefCondition('higher-timeframe bias agrees', met: true),
        const BriefCondition('no high-impact news in 30 min', met: false),
      ],
      losses: day.lossStreak,
      lossesToCooldown: 3,
      score: 812, // sample data, labelled as such on screen
      streak: null, // TODO(next-slice): "[n] days" from the grid
    );
  }
}

/// Two decimals, so floating-point noise never reaches the screen.
double _round2(double v) => double.parse(v.toStringAsFixed(2));

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// "tomorrow at [07:30]": the user's open time, else the first session's.
String tomorrowOpenTime(ProfileDoji p) {
  if (p.theOpenTime != null) return p.theOpenTime!;
  return hhmm(openReferenceMinutes(p.sessions, userZoneFromProfile(p)));
}

/// 12 weeks × 7 days, column-major (Mon first), today in the last column.
/// Levels are a SAMPLE pattern like the design's; TODO(next-slice): real
/// days from the closed-day log.
List<GridCellState> sampleGrid({required DateTime today, required bool zero, required bool closed}) {
  const weeks = 12;
  final todayIndex = (weeks - 1) * 7 + (today.weekday - 1);
  return List.generate(weeks * 7, (i) {
    if (i > todayIndex) return GridCellState.future;
    if (i == todayIndex) return zero || closed ? GridCellState.l4 : GridCellState.today;
    if (zero) return GridCellState.l0;
    final v = (i * 7 + (i % 5) * 3 + (i >> 3)) % 9;
    final level = v < 1
        ? 0
        : v < 3
        ? 1
        : v < 5
        ? 2
        : v < 7
        ? 3
        : 4;
    return GridCellState.values[level];
  });
}
