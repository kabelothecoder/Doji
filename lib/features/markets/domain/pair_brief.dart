import '../../coach/domain/coach.dart';
import '../../journal/domain/trade.dart';
import '../../onboarding/domain/profile_doji.dart';
import 'candle.dart';
import 'news.dart';

/// Design system `ConditionRow(status)`: shape + word + colour, never colour alone.
enum ConditionStatus {
  met('MET'),
  notMet('NOT MET'),
  waiting('WAITING');

  const ConditionStatus(this.label);

  /// The word on the row.
  final String label;
}

/// One of "your entry conditions", measured now.
class EntryCondition {
  const EntryCondition(this.text, this.status);

  /// Sentence case, as the handoff writes them ("London session is open").
  final String text;
  final ConditionStatus status;

  bool get met => status == ConditionStatus.met;
}

/// A price level from the trader's strategy, drawn on the chart (green dashed).
class StrategyLevels {
  const StrategyLevels({
    required this.range,
    required this.highLabel,
    required this.lowLabel,
    required this.spoken,
  });

  final PriceRange range;

  /// Axis tags ('ASIA HI', 'ASIA LO').
  final String highLabel;
  final String lowLabel;

  /// For the chart's screen-reader label ('your asian range levels').
  final String spoken;
}

/// When 1b's "check again" points to, and why.
class CheckAgain {
  const CheckAgain(this.at, this.why);

  /// UTC.
  final DateTime at;

  /// "after the news window closes".
  final String why;
}

/// Handoff 1b's doji brief for one instrument: five sections measured
/// against the trader's strategy and rules. Never says where price will go.
class PairBrief {
  const PairBrief({
    required this.symbol,
    required this.updatedAt,
    required this.context,
    required this.strategyName,
    required this.strategy,
    required this.conditions,
    required this.riskNote,
    required this.checkAgain,
    required this.followUps,
    required this.levels,
    required this.nextNews,
    required this.dayDone,
  });

  final String symbol;

  /// UTC.
  final DateTime updatedAt;

  /// 01 · market context.
  final String context;

  /// The strategy chip on 02; null when none is described.
  final String? strategyName;

  /// 02 · what your strategy says.
  final String strategy;

  /// 03 · your entry conditions.
  final List<EntryCondition> conditions;

  /// 04 · risk note.
  final String riskNote;

  /// 05 · check again; null when the plan is done for today.
  final CheckAgain? checkAgain;

  /// The suggested questions under the brief.
  final List<String> followUps;

  /// Strategy levels for the chart; null when the strategy names none doji measures.
  final StrategyLevels? levels;

  /// The release in progress or the next one within a day: the orange chip and line.
  final NewsEvent? nextNews;

  /// Max trades or the daily loss limit reached: the plan is done for today.
  final bool dayDone;

  int get metCount => conditions.where((c) => c.met).length;
  Iterable<EntryCondition> get waiting => conditions.where((c) => c.status == ConditionStatus.waiting);
}

/// What a brief is measured against.
class BriefRequest {
  const BriefRequest({required this.symbol, required this.profile, required this.trades, required this.now});

  final String symbol;
  final ProfileDoji profile;

  /// The journal; only today's count.
  final List<Trade> trades;
  final DateTime now;

  CoachContext get coach => CoachContext.from(profile, trades: trades, now: now);
}

/// Writes 1b's brief. The UI only sees this.
///
/// [FakeBrief] is the only implementation: worked out on the device from
/// profile.doji, the journal, sample prices and the sample news calendar.
/// TODO(next-slice): `SupabaseBrief`, the `ai-brief` edge function (the LLM
/// writes 01, 02 and 04 from the same inputs, the same no-calls rule);
/// conditions stay measured, not written. Keep the fake as the offline fallback.
abstract interface class BriefSource {
  Future<PairBrief> brief(BriefRequest request);
}

/// One line of the brief chat.
class BriefTurn {
  const BriefTurn({required this.fromYou, required this.text});

  final bool fromYou;
  final String text;
}

/// The chat under a brief ("ask about this brief"): scoped to that brief.
/// The UI only sees this. TODO(next-slice): the `ai-brief` edge function's
/// chat, streamed.
abstract interface class BriefChat {
  Future<String> reply(PairBrief brief, BriefRequest request, List<BriefTurn> history, String message);
}
