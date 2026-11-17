import '../domain/rate_source.dart';

/// PLACEHOLDER rates, fixed in the app and only roughly right. Tests use it;
/// the app sizes with [LiveRateSource] (live_rate_source.dart) only.
class PlaceholderRateSource implements RateSource {
  const PlaceholderRateSource();

  /// Units of each currency per 1 USD.
  static const Map<String, double> perUsd = {
    'USD': 1,
    'ZAR': 18.5,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 150,
    'CAD': 1.36,
    'CHF': 0.88,
    'AUD': 1.52,
  };

  @override
  double? rate(String from, String to) {
    final f = from.toUpperCase(), t = to.toUpperCase();
    if (f == t) return 1;
    final perFrom = perUsd[f], perTo = perUsd[t];
    if (perFrom == null || perTo == null) return null;
    return perTo / perFrom;
  }

  @override
  Future<void> prepare(String from, String to) async {}
}
