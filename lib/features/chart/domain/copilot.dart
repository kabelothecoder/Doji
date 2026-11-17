import '../../coach/domain/coach.dart';
import '../../markets/domain/candle.dart';
import '../../markets/domain/pair_brief.dart';
import 'drawing.dart';

/// What the co-pilot is told about one finished drawing. Facts the device
/// measured and the trader's own words; never a price to predict from.
class CopilotRequest {
  const CopilotRequest({
    required this.symbol,
    required this.timeframe,
    required this.drawing,
    required this.reason,
    required this.strategyWords,
    required this.conditions,
    required this.coach,
    this.r,
    this.lastPrice,
  });

  final String symbol;
  final Timeframe timeframe;
  final Drawing drawing;

  /// The trader's answer to "what is this?".
  final String reason;

  /// The active account's strategy, in the trader's words ('' when none).
  final String strategyWords;

  /// The active account's conditions, measured now.
  final List<EntryCondition> conditions;

  /// Today's limits: trades vs max, loss vs the stricter limit, loss streak.
  final CoachContext coach;

  /// A position's planned R.
  final double? r;
  final double? lastPrice;
}

enum CopilotKind {
  /// One reflective question.
  question,

  /// A reminder of the trader's own rule or limit.
  rule,

  /// Not the co-pilot's words: a limit reached, offline.
  notice,
}

class CopilotReply {
  const CopilotReply(this.text, {this.kind = CopilotKind.question, this.crisis = false});

  final String text;
  final CopilotKind kind;
  final bool crisis;
}

/// Holds the trader's reason for a mark up against their own written
/// strategy. The UI only sees this. It never rates the setup or its odds.
abstract interface class Copilot {
  Future<CopilotReply> reflect(CopilotRequest request);
}

/// Words that rate a setup or its odds. The co-pilot never says them; a reply
/// that does is replaced. Same pattern as `ratesOdds` in
/// supabase/functions/_shared/guard.ts.
final _odds = RegExp(
  r'\b\d+\s?%\s+(chance|probab\w*|likel\w*|of (these|them|trades|setups|the time))|\b(likely|unlikely|probab\w*|odds|chances?|high[- ]quality|low[- ]quality|good setup|bad setup|'
  r'strong setup|weak setup|will (go|hit|reach|break|reverse|bounce|work))\b',
  caseSensitive: false,
);

bool ratesOdds(String text) => _odds.hasMatch(text);
