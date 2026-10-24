import 'package:clock/clock.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../markets/domain/time_zones.dart';

/// The trader's own "when I trade" preference: the big session opens, each in
/// its city's real time zone, so daylight saving moves them for you
/// (London 08:00 is 07:00 UTC in summer and 08:00 UTC in winter).
///
/// Nominal opens: Sydney 07:00, Tokyo 09:00, London 08:00, New York 08:00 local.
/// What a market is doing right now is `MarketHours`' job, not this enum's.
enum TradingSession {
  sydney('sydney', 'Sydney', TimeZones.sydney, 7 * 60),
  tokyo('tokyo', 'Tokyo', TimeZones.tokyo, 9 * 60),
  london('london', 'London', TimeZones.london, 8 * 60),
  newYork('new_york', 'New York', TimeZones.newYork, 8 * 60),
  aroundJob('around_job', 'around my job', null, null);

  const TradingSession(this.key, this.label, this.zoneId, this.openLocalMinutes);

  final String key;
  final String label;

  /// IANA zone of the session's city; null for "around my job".
  final String? zoneId;

  /// Open, in minutes after midnight in [zoneId].
  final int? openLocalMinutes;

  static TradingSession? fromKey(String key) => TradingSession.values.where((s) => s.key == key).firstOrNull;

  /// The instant this session opens on the calendar day of [now] in its own
  /// city; null for "around my job".
  DateTime? openInstant([DateTime? now]) {
    final id = zoneId, minutes = openLocalMinutes;
    if (id == null || minutes == null) return null;
    final location = TimeZones.find(id);
    if (location == null) return null;
    final day = TimeZones.inZone(now ?? clock.now(), location);
    return tz.TZDateTime(location, day.year, day.month, day.day, minutes ~/ 60, minutes % 60).toUtc();
  }

  /// When it opens on the clock of [zone]: minutes after local midnight, on
  /// the day of [now] (default: today). Null for "around my job".
  int? localOpen(UserZone zone, [DateTime? now]) {
    final open = openInstant(now);
    return open == null ? null : zone.minuteOfDayAt(open);
  }
}

String hhmm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// "UTC+2", "UTC-5:30", "UTC".
String utcLabel(int offsetMinutes) {
  if (offsetMinutes == 0) return 'UTC';
  final sign = offsetMinutes > 0 ? '+' : '-';
  final abs = offsetMinutes.abs();
  final h = abs ~/ 60, m = abs % 60;
  return 'UTC$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
}

/// The session whose open comes first in the trader's day, ignoring "around
/// my job" (it has no fixed open).
TradingSession? firstSession(List<String> keys, UserZone zone, [DateTime? now]) {
  final fixed =
      keys
          .map(TradingSession.fromKey)
          .whereType<TradingSession>()
          .where((s) => s.openLocalMinutes != null)
          .toList()
        ..sort((a, b) => a.localOpen(zone, now)!.compareTo(b.localOpen(zone, now)!));
  return fixed.firstOrNull;
}

/// Reference time for The Open: the first session's open on the trader's
/// clock, or 08:00 when they only trade around their job.
int openReferenceMinutes(List<String> keys, UserZone zone, [DateTime? now]) =>
    firstSession(keys, zone, now)?.localOpen(zone, now) ?? 8 * 60;
