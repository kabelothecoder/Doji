import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/news.dart';
import '../domain/time_zones.dart';

/// SAMPLE high-impact news: fixed weekly release times in each currency's
/// own zone (so daylight saving moves them), not a real calendar. Briefs that
/// use it say "sample calendar". TODO(next-slice): a real feed ([NewsCalendar]).
class SampleNewsCalendar implements NewsCalendar {
  const SampleNewsCalendar();

  @override
  bool get isSample => true;

  /// (currency, zone, weekdays, hour, minute).
  static const _releases = [
    ('USD', TimeZones.newYork, [1, 2, 3, 4, 5], 8, 30),
    ('USD', TimeZones.newYork, [3], 14, 0),
    ('EUR', 'Europe/Berlin', [2, 4], 10, 0),
    ('GBP', TimeZones.london, [2, 4], 7, 0),
    ('JPY', TimeZones.tokyo, [1, 3], 8, 50),
    ('AUD', TimeZones.sydney, [2, 4], 11, 30),
    ('CAD', TimeZones.newYork, [5], 8, 30),
    ('CHF', 'Europe/Zurich', [4], 9, 30),
  ];

  @override
  Future<List<NewsEvent>> highImpact({
    required Set<String> currencies,
    required DateTime from,
    required DateTime to,
  }) async {
    final out = <NewsEvent>[];
    final start = from.toUtc(), end = to.toUtc();
    for (final (currency, zoneId, weekdays, hour, minute) in _releases) {
      if (!currencies.contains(currency)) continue;
      final zone = TimeZones.find(zoneId);
      if (zone == null) continue;
      // Every calendar day in that zone that the window touches.
      final first = TimeZones.inZone(start.subtract(const Duration(days: 1)), zone);
      for (var d = 0; d <= end.difference(start).inDays + 2; d++) {
        final day = tz.TZDateTime(zone, first.year, first.month, first.day + d);
        if (!weekdays.contains(day.weekday)) continue;
        final at = tz.TZDateTime(zone, day.year, day.month, day.day, hour, minute).toUtc();
        if (at.isBefore(start) || !at.isBefore(end)) continue;
        out.add(
          NewsEvent(at: at, currency: currency, title: '${currency.toLowerCase()} high-impact release'),
        );
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}

final newsCalendarProvider = Provider<NewsCalendar>((ref) => const SampleNewsCalendar());
