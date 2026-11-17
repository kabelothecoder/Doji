/// Where exchange rates come from. RiskSizing only knows this interface.
abstract interface class RateSource {
  /// How many units of [to] one unit of [from] buys (3-letter codes, any
  /// case), or null when the pair is unknown or its rate is stale. Same
  /// currency is always 1.
  double? rate(String from, String to);

  /// Fetches [from] → [to] if this source can and has no fresh rate yet.
  /// Never throws: a pair it can't get stays null.
  Future<void> prepare(String from, String to);
}
