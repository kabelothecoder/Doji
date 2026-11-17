import 'pair_brief.dart';

/// Design `StrategyStateBadge` (Doji Core Tabs › 01 watchlist): how far one
/// instrument is through the trader's entry conditions, from the brief's
/// own measured conditions. A count of rules kept, never a call.
enum StrategyState {
  /// Every condition is met.
  met('conditions met'),

  /// At least half met, not all.
  forming('forming'),

  /// Fewer than half met (or nothing to measure yet).
  waiting('waiting');

  const StrategyState(this.label);

  /// The word on the badge; the badge is never colour alone.
  final String label;

  static StrategyState of(List<EntryCondition> conditions) {
    if (conditions.isEmpty) return waiting;
    final met = conditions.where((c) => c.met).length;
    if (met == conditions.length) return StrategyState.met;
    return met * 2 >= conditions.length ? forming : waiting;
  }
}
