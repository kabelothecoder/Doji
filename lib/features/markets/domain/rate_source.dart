/// Where exchange rates come from. RiskSizing only knows this interface.
abstract interface class RateSource {
  /// How many units of [to] one unit of [from] buys (3-letter codes, any
  /// case), or null when the pair is unknown. Same currency is always 1.
  double? rate(String from, String to);
}
