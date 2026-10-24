import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rate_source.dart';

/// PLACEHOLDER rates, fixed in the app and only roughly right: good enough to
/// exercise sizing in other currencies, NOT to size a real trade.
///
/// TODO(next-slice): live rates. Fetch from a rates API through a Supabase
/// edge function (so the key stays off the device), cache with a timestamp,
/// refuse to size when the quote is stale, and show the rate used.
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
}

final rateSourceProvider = Provider<RateSource>((ref) => const PlaceholderRateSource());
