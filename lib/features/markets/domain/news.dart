import 'instrument.dart';

/// Minutes either side of high-impact news when the trader's rules say no
/// entries. Home's rules list says the same.
/// TODO(next-slice): a setting, stored in profile.doji › rules.
const int kNewsBufferMinutes = 30;

/// One high-impact release.
class NewsEvent {
  const NewsEvent({required this.at, required this.currency, required this.title});

  /// Release time, UTC.
  final DateTime at;

  /// 'USD', 'EUR', 'GBP'…
  final String currency;

  /// Short and lowercase ('usd high-impact release').
  final String title;

  DateTime get windowStart => at.subtract(const Duration(minutes: kNewsBufferMinutes));
  DateTime get windowEnd => at.add(const Duration(minutes: kNewsBufferMinutes));

  /// [now] is inside the no-entries window around the release.
  bool covers(DateTime now) => !now.isBefore(windowStart) && now.isBefore(windowEnd);
}

/// The economic calendar. The UI only sees this.
///
/// [SampleNewsCalendar] is the only implementation (fixed weekly times,
/// labelled sample). TODO(next-slice): a real calendar feed through a
/// Supabase edge function, cached per day.
abstract interface class NewsCalendar {
  bool get isSample;

  /// High-impact events between [from] and [to] for any of [currencies],
  /// soonest first.
  Future<List<NewsEvent>> highImpact({
    required Set<String> currencies,
    required DateTime from,
    required DateTime to,
  });
}

/// The currencies whose news moves [instrument]: both legs of a forex pair,
/// the quote currency of metals, indices, oil and crypto. Synthetic indices
/// run on Deriv's own generator, so no news moves them: empty.
Set<String> newsCurrencies(Instrument? instrument) {
  if (instrument == null) return const {};
  return switch (instrument.assetClass) {
    AssetClass.synthetic => const {},
    AssetClass.forex when instrument.symbol.length == 6 => {
      instrument.symbol.substring(0, 3),
      instrument.symbol.substring(3),
    },
    _ => {instrument.quoteCurrency},
  };
}
