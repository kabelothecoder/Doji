import 'dart:math';

import '../../accounts/domain/trading_account.dart';
import '../../backtest/domain/backtest.dart';
import '../../journal/domain/process_grade.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/instrument_catalog.dart';
import '../../markets/domain/london_break.dart';
import '../../markets/domain/rate_source.dart';
import '../../markets/domain/risk_sizing.dart';

// --- replay practice ----------------------------------------------------------

/// One position the trader placed in a gym replay, as doji saw it.
class PracticeTake {
  const PracticeTake({required this.entryAt, required this.setupThere, required this.stopMoved});

  final DateTime entryAt;

  /// A measured setup of the trader's strategy was at this bar (± 3 bars).
  final bool setupThere;

  /// The stop was moved after the entry bar showed.
  final bool stopMoved;
}

/// A practice scored on process, never on the result. Practice positions are
/// sized from the account's risk %, so size is kept by construction (the size
/// drill practises it).
class PracticeScore {
  const PracticeScore({
    required this.grade,
    required this.reasons,
    required this.missed,
    required this.taken,
  });

  /// The lowest grade of the positions taken; A when the trader took none and
  /// none was there.
  final ProcessGrade grade;

  /// One line per check, kept or broken.
  final List<ProcessReason> reasons;

  /// Setups the trader let pass. Shown, not graded: skipping is never a mistake.
  final int missed;
  final int taken;
}

PracticeScore scorePractice({required List<PracticeTake> takes, required int setups, int? maxTrades}) {
  var worst = ProcessGrade.a;
  final reasons = <ProcessReason>[];
  for (var i = 0; i < takes.length; i++) {
    final t = takes[i];
    final mistakes = [if (t.stopMoved) 'moved stop', if (maxTrades != null && i >= maxTrades) 'overtrading'];
    final g = ProcessGrade.of(
      plan: mistakes.isEmpty ? PlanFollowed.yes : PlanFollowed.partly,
      mistakes: mistakes,
      setup: t.setupThere ? 'your setup' : kNoSetup,
    );
    if (g.index > worst.index) worst = g;
    final n = i + 1;
    reasons
      ..add(
        ProcessReason(
          t.setupThere ? 'position $n: your setup was there' : 'position $n: no setup from your strategy',
          kept: t.setupThere,
        ),
      )
      ..add(
        ProcessReason(
          t.stopMoved ? 'position $n: stop moved after entry' : 'position $n: stop left where planned',
          kept: !t.stopMoved,
        ),
      );
    if (maxTrades != null && i >= maxTrades) {
      reasons.add(ProcessReason('position $n: past your max of $maxTrades trades', kept: false));
    }
  }
  final matched = takes.where((t) => t.setupThere).length;
  final missed = max(0, setups - matched);
  if (takes.isEmpty) {
    reasons.add(ProcessReason(setups == 0 ? 'no setup, no trade' : 'no positions taken', kept: true));
  }
  return PracticeScore(grade: worst, reasons: reasons, missed: missed, taken: takes.length);
}

// --- daily drills ---------------------------------------------------------------

enum DrillKind {
  spotSetup('spot your setup'),
  placeStop('place the stop'),
  sizeTrade('size the trade'),
  afterLosses('after losses');

  const DrillKind(this.label);

  final String label;

  static DrillKind? fromName(String? n) => values.where((v) => v.name == n).firstOrNull;
}

/// One drill question with its own answer. [check] never needs the network.
class DrillItem {
  const DrillItem({
    required this.kind,
    required this.question,
    required this.explain,
    this.symbol,
    this.bars = const [],
    this.yes,
    this.price,
    this.tolerance = 0,
  });

  final DrillKind kind;
  final String question;

  /// Why the answer is what it is, shown after answering.
  final String explain;
  final String? symbol;

  /// The frozen chart; never anything after the question's moment.
  final List<Candle> bars;

  /// Yes/no drills.
  final bool? yes;

  /// Price or size drills: the answer and how far off still counts.
  final double? price;
  final double tolerance;

  bool get isYesNo => yes != null;

  bool checkYes(bool answer) => answer == yes;

  bool checkNumber(double answer) => price != null && (answer - price!).abs() <= tolerance;
}

/// A set of 3–5 drills for one local day. Spot / stop / size need cached
/// history with measured setups; the after-losses drills only need the
/// account's own limits.
List<DrillItem> buildDrills({
  required TradingAccount account,
  required BacktestResult? result,
  required Map<String, List<Candle>> history,
  required Timeframe timeframe,
  required RateSource rates,
  required int seed,
}) {
  final rnd = Random(seed);
  final out = <DrillItem>[];
  final setups = [...?result?.trades]..shuffle(rnd);

  // Spot your setup: one where a setup was next, one where none was.
  if (setups.isNotEmpty) {
    final s = setups.first;
    final bars = history[s.symbol] ?? const [];
    final i = lowerBound(bars, s.entryAt);
    if (i > 20) {
      out.add(
        DrillItem(
          kind: DrillKind.spotSetup,
          symbol: s.symbol,
          bars: bars.sublist(i - 60 < 0 ? 0 : i - 60, i),
          yes: true,
          question: 'the last bar just closed. are your conditions all met for an entry on the next bar?',
          explain:
              'yes. every condition doji can measure was met here, so the backtest entered on the next bar.',
        ),
      );
    }
    // A "no": a bar before the London open, while the Asian range was still
    // forming, so a break of it could not have happened yet.
    for (var tries = 0; tries < 60 && history.isNotEmpty; tries++) {
      final sym = history.keys.elementAt(rnd.nextInt(history.length));
      final b = history[sym]!;
      if (b.length < 80) continue;
      final j = 60 + rnd.nextInt(b.length - 60);
      final w = LondonBreak.windowFor(LondonBreak.lastTokyoOpen(b[j].at));
      if (b[j].at.isBefore(w.tokyoOpen.add(timeframe.duration * 2)) || !b[j].at.isBefore(w.londonOpen)) {
        continue;
      }
      out.add(
        DrillItem(
          kind: DrillKind.spotSetup,
          symbol: sym,
          bars: b.sublist(j - 60, j),
          yes: false,
          question: 'the last bar just closed. are your conditions all met for an entry on the next bar?',
          explain:
              'no. the asian range was still forming, before the london open, so it could not have broken yet.',
        ),
      );
      break;
    }
  }

  // Place the stop: where the stop rule puts it, within a quarter of the risk.
  if (setups.isNotEmpty) {
    final s = setups.length > 1 ? setups[1] : setups.first;
    final bars = history[s.symbol] ?? const [];
    final i = lowerBound(bars, s.entryAt);
    final risk = (s.entry - s.stop).abs();
    out.add(
      DrillItem(
        kind: DrillKind.placeStop,
        symbol: s.symbol,
        bars: bars.sublist(i - 60 < 0 ? 0 : i - 60, i),
        price: s.stop,
        tolerance: risk / 4,
        question: 'entry at ${_p(s.entry)}. where does your stop rule put the stop? type the price.',
        explain: 'your stop rule puts it at ${_p(s.stop)}; anything within ${_p(risk / 4)} of it counts.',
      ),
    );
  }

  // Size the trade for the active account.
  final riskPct = account.rules?.riskPerTrade;
  final size = account.startingSize;
  if (setups.isNotEmpty && riskPct != null && size != null) {
    for (final s in setups) {
      final inst = instrumentBySymbol(s.symbol);
      if (inst == null) continue;
      final lots = RiskSizing.contractsForRisk(
        instrument: inst,
        accountBalance: size,
        accountCurrency: account.accountCurrency,
        riskPercent: riskPct,
        stopDistance: (s.entry - s.stop).abs(),
        rates: rates,
      );
      if (lots == null) continue;
      out.add(
        DrillItem(
          kind: DrillKind.sizeTrade,
          symbol: s.symbol,
          price: lots,
          tolerance: max(0.01, lots * 0.05),
          question:
              '${instrumentLabel(s.symbol)}: entry ${_p(s.entry)}, stop ${_p(s.stop)}. account ${size.toStringAsFixed(0)} '
              '${account.accountCurrency}, risk ${_n(riskPct)}%. what size? type it in lots.',
          explain: '${lots.toStringAsFixed(2)} lots loses ${_n(riskPct)}% at the stop. within 5% counts.',
        ),
      );
      break;
    }
  }

  // After losses: rehearse the account's own stop-for-the-day rule.
  for (final losses in [2, 1, 3]) {
    if (out.length >= 5) break;
    out.add(afterLossesDrill(account, losses: losses));
  }
  return out.take(5).toList();
}

/// "[losses] losses today, a setup appears: take it?", answered by the
/// account's max trades and stricter daily loss limit.
DrillItem afterLossesDrill(TradingAccount account, {required int losses}) {
  final risk = account.rules?.riskPerTrade ?? 1;
  final max = account.rules?.maxTradesPerDay;
  final limit = account.strictestDailyLossPct;
  final lost = losses * risk;
  final maxHit = max != null && losses >= max;
  final limitHit = limit != null && lost >= limit;
  final rules = [
    if (max != null) 'max $max trades a day',
    if (limit != null) 'stop for the day at -${_n(limit)}%',
  ];
  final why = maxHit
      ? 'no. that is $losses trades, your max is $max: the day is done.'
      : limitHit
      ? 'no. -${_n(lost)}% reaches your ${_n(limit)}% daily limit: the day is done.'
      : rules.isEmpty
      ? 'your rules allow it, but this account has no max trades or daily loss limit set. setting one is part of the plan.'
      : 'yes, if it is your setup: -${_n(lost)}% and $losses trades are inside your rules (${rules.join(', ')}).';
  return DrillItem(
    kind: DrillKind.afterLosses,
    yes: !(maxHit || limitHit),
    question:
        '$losses ${losses == 1 ? 'loss' : 'losses'} today, -${_n(lost)}% in all. your setup appears. do your rules let you take it?',
    explain: why,
  );
}

String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
String _p(double v) => v.abs() >= 1000
    ? v.toStringAsFixed(1)
    : v.abs() >= 10
    ? v.toStringAsFixed(2)
    : v.toStringAsFixed(5);

// --- streak -------------------------------------------------------------------

/// Days in a row with a finished drill set, counting back from [today] (or
/// from yesterday while today's set is not done yet). Dates are local days.
int drillStreak(Set<DateTime> days, DateTime today) {
  DateTime d(DateTime t) => DateTime(t.year, t.month, t.day);
  var day = d(today);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var n = 0;
  while (days.contains(day)) {
    n++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return n;
}
