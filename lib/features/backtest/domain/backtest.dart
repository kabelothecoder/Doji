import '../../accounts/domain/condition_eval.dart';
import '../../accounts/domain/trading_account.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/london_break.dart';
import '../../markets/domain/news.dart';
import '../../onboarding/domain/profile_doji.dart';
import '../../onboarding/domain/sessions.dart';
import 'fills.dart';

/// Under this many setups a sample says so plainly.
const int kSmallSample = 30;

/// One setup the backtest (or a replay) took, and how it ended.
class BacktestTrade {
  const BacktestTrade({
    required this.symbol,
    required this.session,
    required this.entryAt,
    required this.entry,
    required this.stop,
    required this.target,
    required this.exitAt,
    required this.exit,
    required this.reason,
  });

  final String symbol;

  /// The session key open at entry ('london'), or '' when none of the four.
  final String session;
  final DateTime entryAt;
  final double entry;
  final double stop;
  final double target;
  final DateTime? exitAt;
  final double? exit;
  final ExitReason reason;

  bool get stopBelow => stop < entry;
  bool get closed => reason != ExitReason.open && exit != null;
  double get r => closed ? rOf(entry: entry, stop: stop, exit: exit!) : 0;

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'session': session,
    'entryAt': entryAt.toUtc().toIso8601String(),
    'entry': entry,
    'stop': stop,
    'target': target,
    'exitAt': exitAt?.toUtc().toIso8601String(),
    'exit': exit,
    'reason': reason.name,
  };

  static BacktestTrade? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['entryAt']}');
    final entry = j['entry'], stop = j['stop'], target = j['target'];
    if (at == null || entry is! num || stop is! num || target is! num || j['symbol'] is! String) return null;
    final exit = j['exit'];
    return BacktestTrade(
      symbol: j['symbol'] as String,
      session: '${j['session'] ?? ''}',
      entryAt: at.toUtc(),
      entry: entry.toDouble(),
      stop: stop.toDouble(),
      target: target.toDouble(),
      exitAt: DateTime.tryParse('${j['exitAt']}')?.toUtc(),
      exit: exit is num ? exit.toDouble() : null,
      reason: ExitReason.fromName(j['reason'] as String?),
    );
  }
}

/// Counts and R of a set of closed trades. Never a hit rate: R and counts only.
class BacktestStats {
  const BacktestStats({
    required this.setups,
    required this.totalR,
    required this.maxLosingStreak,
    required this.maxDrawdownR,
  });

  factory BacktestStats.of(Iterable<BacktestTrade> trades) {
    var total = 0.0, peak = 0.0, dd = 0.0;
    var streak = 0, maxStreak = 0, n = 0;
    for (final t in trades) {
      if (!t.closed) continue;
      n++;
      total += t.r;
      if (total > peak) peak = total;
      if (peak - total > dd) dd = peak - total;
      streak = t.r < 0 ? streak + 1 : 0;
      if (streak > maxStreak) maxStreak = streak;
    }
    return BacktestStats(setups: n, totalR: total, maxLosingStreak: maxStreak, maxDrawdownR: dd);
  }

  final int setups;
  final double totalR;
  final int maxLosingStreak;

  /// Largest fall of the running R total from its high.
  final double maxDrawdownR;

  double get averageR => setups == 0 ? 0 : totalR / setups;
  bool get smallSample => setups < kSmallSample;
}

/// What the automatic backtest runs: an account's conditions and exits over
/// cached history.
class BacktestInput {
  const BacktestInput({
    required this.conditions,
    required this.exits,
    required this.timeframe,
    required this.candles,
    required this.from,
    required this.to,
    this.traderSessions = const [],
    this.rules,
    this.dailyLossLimitPct,
    this.news = const {},
  });

  final List<StrategyCondition> conditions;
  final ExitRules exits;
  final Timeframe timeframe;

  /// Per symbol, oldest first.
  final Map<String, List<Candle>> candles;
  final DateTime from;
  final DateTime to;
  final List<String> traderSessions;
  final TradingRules? rules;

  /// The stricter of the trader's and the firm's daily loss limit.
  final double? dailyLossLimitPct;

  /// High-impact news per symbol. A symbol missing here has no news check.
  final Map<String, List<NewsEvent>> news;
}

class BacktestResult {
  const BacktestResult({
    required this.trades,
    required this.untested,
    required this.measurableEntry,
    required this.daysTested,
    required this.skippedNoRoom,
    required this.from,
    required this.to,
  });

  /// Oldest first.
  final List<BacktestTrade> trades;

  /// The trader's manual conditions: "not tested, needs replay".
  final List<String> untested;

  /// False when nothing in the strategy marks an entry doji can measure (only a
  /// range break does today): then there are no automatic setups at all.
  final bool measurableEntry;
  final int daysTested;

  /// Setups left out because the stop rule put the stop on the wrong side.
  final int skippedNoRoom;
  final DateTime from;
  final DateTime to;

  BacktestStats get stats => BacktestStats.of(trades);

  Map<String, BacktestStats> get bySession => _group((t) => t.session.isEmpty ? 'other hours' : t.session);
  Map<String, BacktestStats> get bySymbol => _group((t) => t.symbol);

  Map<String, BacktestStats> _group(String Function(BacktestTrade) key) {
    final groups = <String, List<BacktestTrade>>{};
    for (final t in trades) {
      groups.putIfAbsent(key(t), () => []).add(t);
    }
    return {for (final e in groups.entries) e.key: BacktestStats.of(e.value)};
  }
}

/// First index in [bars] (oldest first) with `at` not before [t].
int lowerBound(List<Candle> bars, DateTime t) {
  var lo = 0, hi = bars.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (bars[mid].at.isBefore(t)) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// The session key open at [t] among the four, or ''. Where two overlap,
/// the one that opened last (London over Tokyo at 08:00 London).
String sessionAt(DateTime t) {
  final open = TradingSession.fixed.where((s) => s.isOpenAt(t)).toList()
    ..sort((a, b) => b.openInstant(t)!.compareTo(a.openInstant(t)!));
  return open.firstOrNull?.key ?? '';
}

class _Candidate {
  _Candidate(this.symbol, this.entryIndex, this.bars, this.lb, this.londonClose);

  final String symbol;
  final int entryIndex;
  final List<Candle> bars;
  final LondonBreak lb;
  final DateTime londonClose;

  DateTime get entryAt => bars[entryIndex].at;
}

/// Runs [input]'s measurable conditions over its history, day by day.
///
/// A setup is a day where every measured condition is met at the entry bar
/// (the london break of the Asian range, with the close back when the
/// strategy asks for it, the session, the news window, trades vs max, the
/// day's loss vs the limit). Entry is the next bar's open; the stop comes from
/// [ExitRules]; exits follow [fillOn]. Manual conditions are not tested.
BacktestResult runBacktest(BacktestInput input) {
  final untested = [
    for (final c in input.conditions)
      if (c.kind == ConditionKind.manual && (c.text?.trim().isNotEmpty ?? false)) c.text!.trim(),
  ];
  final rangeRule = input.conditions.where((c) => c.kind == ConditionKind.rangeBreak).firstOrNull;
  final from = input.from.toUtc(), to = input.to.toUtc();
  if (rangeRule == null) {
    return BacktestResult(
      trades: const [],
      untested: untested,
      measurableEntry: false,
      daysTested: 0,
      skippedNoRoom: 0,
      from: from,
      to: to,
    );
  }
  final tf = input.timeframe;
  final risk = input.rules?.riskPerTrade ?? 1;
  final trades = <BacktestTrade>[];
  var days = 0, noRoom = 0;

  // Each Tokyo open in the period starts one trading day.
  final opens = <DateTime>{};
  for (var t = from; t.isBefore(to); t = t.add(const Duration(days: 1))) {
    final o = TradingSession.tokyo.openInstant(t);
    if (o != null && !o.isBefore(from) && o.isBefore(to)) opens.add(o);
  }

  for (final tokyoOpen in opens.toList()..sort()) {
    final w = LondonBreak.windowFor(tokyoOpen);
    if (w.londonClose.isAfter(to)) continue;
    final candidates = <_Candidate>[];
    var anyRange = false;
    for (final MapEntry(key: symbol, value: bars) in input.candles.entries) {
      final a = lowerBound(bars, w.tokyoOpen),
          b = lowerBound(bars, w.londonOpen),
          c = lowerBound(bars, w.londonClose);
      final lb = LondonBreak.measure(
        asian: bars.sublist(a, b),
        london: bars.sublist(b, c),
        tf: tf,
        now: w.londonClose,
        londonOpen: w.londonOpen,
        londonClose: w.londonClose,
      );
      if (lb.range == null) continue;
      anyRange = true;
      if (lb.breakAt == null) continue;
      if (rangeRule.closeBack && lb.retestAt == null) continue;
      final entryAt = rangeRule.closeBack ? lb.retestAt! : lb.breakAt!.add(tf.duration);
      final i = lowerBound(bars, entryAt);
      if (i >= c) continue; // no bar left in the session to enter on
      candidates.add(_Candidate(symbol, i, bars, lb, w.londonClose));
    }
    if (anyRange) days++;
    candidates.sort((x, y) => x.entryAt.compareTo(y.entryAt));

    final today = <BacktestTrade>[];
    for (final k in candidates) {
      final at = k.entryAt;
      final closedPct = [
        for (final t in today)
          if (t.exitAt != null && !t.exitAt!.isAfter(at)) t.r * risk,
      ].fold(0.0, (s, v) => s + v);
      // The account's own limits always apply, listed as conditions or not.
      final max = input.rules?.maxTradesPerDay;
      final limit = input.dailyLossLimitPct;
      if (max != null && today.length >= max) continue;
      if (limit != null && closedPct < 0 && -closedPct >= limit) continue;
      final events = input.news[k.symbol];
      final measured = measureConditions(
        input.conditions,
        ConditionFacts(
          now: at,
          marketOpen: true,
          traderSessions: input.traderSessions,
          tradesToday: today.length,
          lossTodayPct: closedPct < 0 ? -closedPct : 0,
          maxTradesPerDay: input.rules?.maxTradesPerDay,
          dailyLossLimitPct: input.dailyLossLimitPct,
          rangeBroke: true,
          closedBack: k.lb.retestAt != null,
          newsKnown: events != null,
          newsInWindow: events?.any((e) => e.covers(at)) ?? false,
          timeframeLabel: tf.label,
        ),
      );
      // Manual conditions read "waiting": they are listed as untested, not guessed.
      final measuredOnly = measured.conditions.where((c) => !c.text.endsWith(kCheckOnYourChart));
      if (!measuredOnly.every((c) => c.met)) continue;

      final range = k.lb.range!;
      final up = k.lb.up!;
      final buffer = input.exits.bufferOfRange * range.size;
      final entry = k.bars[k.entryIndex].open;
      final stop = switch ((input.exits.stop, up)) {
        (StopRule.brokenLevel, true) => range.high - buffer,
        (StopRule.brokenLevel, false) => range.low + buffer,
        (StopRule.rangeOpposite, true) => range.low - buffer,
        (StopRule.rangeOpposite, false) => range.high + buffer,
      };
      if (up ? stop >= entry : stop <= entry) {
        noRoom++;
        continue;
      }
      final target = entry + (entry - stop) * input.exits.targetR;
      final t = _simulate(k, entry: entry, stop: stop, target: target, maxBars: input.exits.maxBarsOpen);
      today.add(t);
      trades.add(t);
    }
  }
  return BacktestResult(
    trades: trades,
    untested: untested,
    measurableEntry: true,
    daysTested: days,
    skippedNoRoom: noRoom,
    from: from,
    to: to,
  );
}

BacktestTrade _simulate(
  _Candidate k, {
  required double entry,
  required double stop,
  required double target,
  int? maxBars,
}) {
  final below = stop < entry;
  var exitAt = k.bars[k.entryIndex].at;
  var exit = entry;
  var reason = ExitReason.sessionEnd;
  for (var i = k.entryIndex, n = 1; i < k.bars.length && k.bars[i].at.isBefore(k.londonClose); i++, n++) {
    final bar = k.bars[i];
    final fill = fillOn(bar, stop: stop, target: target, stopBelow: below);
    exitAt = bar.at;
    if (fill != null) {
      exit = fill.price;
      reason = fill.reason;
      break;
    }
    exit = bar.close;
    if (maxBars != null && n >= maxBars) {
      reason = ExitReason.maxBars;
      break;
    }
  }
  return BacktestTrade(
    symbol: k.symbol,
    session: sessionAt(k.entryAt),
    entryAt: k.entryAt,
    entry: entry,
    stop: stop,
    target: target,
    exitAt: exitAt,
    exit: exit,
    reason: reason,
  );
}
