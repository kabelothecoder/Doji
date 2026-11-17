import 'profile_doji.dart';

/// Turns a strategy described in the user's own words into structured,
/// editable fields (setup, timeframe, entry, stop, target).
///
/// Implementations:
/// - `MockStrategyParser` (data/): keyword matching, offline, ships now.
/// - `SupabaseStrategyReader` (accounts/data/): Gemini through the
///   `ai-strategy` edge function, the mock as its fallback.
abstract interface class StrategyParser {
  Future<ParsedStrategy> parse(String description);
}

/// Starting points for "or start from a template". Structures only; the
/// user edits every field, and none of it is a trade call.
const Map<String, ParsedStrategy> strategyTemplates = {
  'sr': ParsedStrategy(
    setup: 'reaction at a marked support or resistance level',
    entry: 'rejection candle closes at the level',
    stop: 'beyond the level',
    target: 'the next level',
  ),
  'smc_ict': ParsedStrategy(
    setup: 'liquidity sweep into an order block (smc/ict)',
    entry: 'market structure shift after the sweep',
    stop: 'beyond the sweep',
    target: 'opposing liquidity',
  ),
  'trend_pullback': ParsedStrategy(
    setup: 'pullback in an established trend',
    entry: 'continuation candle after the pullback',
    stop: 'beyond the pullback',
    target: '2R',
  ),
  'breakout': ParsedStrategy(
    setup: 'breakout of a consolidation range',
    entry: 'candle closes beyond the range',
    stop: 'back inside the range',
    target: '2R',
  ),
};

/// Chip labels, handoff 4a.
const Map<String, String> strategyTemplateLabels = {
  'sr': 'support & resistance',
  'smc_ict': 'SMC/ICT',
  'trend_pullback': 'trend pullback',
  'breakout': 'breakout',
  'none': "I don't have one yet",
};
