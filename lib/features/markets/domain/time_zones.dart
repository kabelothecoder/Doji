import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The IANA zone database (with daylight saving), loaded once on first use.
///
/// Exchange and session zones are named here; a trader's own zone comes from
/// the device (`flutter_timezone`) as an IANA id, or from a manual UTC offset.
abstract final class TimeZones {
  static const london = 'Europe/London';
  static const newYork = 'America/New_York';
  static const chicago = 'America/Chicago';
  static const sydney = 'Australia/Sydney';
  static const tokyo = 'Asia/Tokyo';

  static bool _ready = false;

  /// Idempotent. About 70 ms the first time, then free.
  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  /// Null for ids the database does not know (manual offsets like "UTC+2",
  /// OS abbreviations, typos).
  static tz.Location? find(String id) {
    ensureInitialized();
    try {
      return tz.getLocation(id);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  /// [instant] as wall-clock time in [location].
  static tz.TZDateTime inZone(DateTime instant, tz.Location location) =>
      tz.TZDateTime.from(instant.toUtc(), location);
}

/// Where the trader is: a real zone (daylight saving follows the calendar)
/// or, when only a manual offset is known, a fixed offset.
class UserZone {
  const UserZone.fixed(int offsetMinutes) : id = null, _location = null, _fixedMinutes = offsetMinutes;

  const UserZone._named(this.id, tz.Location this._location) : _fixedMinutes = 0;

  /// [id] is used when the database knows it; otherwise [offsetMinutes]
  /// (what the user picked by hand, or the offset when the zone was detected).
  factory UserZone.from({String? id, int? offsetMinutes}) {
    final location = id == null ? null : TimeZones.find(id);
    if (id != null && location != null) return UserZone._named(id, location);
    return UserZone.fixed(offsetMinutes ?? 0);
  }

  /// IANA id, or null for a fixed offset.
  final String? id;
  final tz.Location? _location;
  final int _fixedMinutes;

  bool get hasDaylightSaving => _location != null;

  /// Offset from UTC in minutes at [instant] (differs summer to winter for a
  /// zone with daylight saving).
  int offsetMinutesAt(DateTime instant) {
    final location = _location;
    if (location == null) return _fixedMinutes;
    return tz.TZDateTime.from(instant.toUtc(), location).timeZoneOffset.inMinutes;
  }

  /// Minutes after local midnight at [instant].
  int minuteOfDayAt(DateTime instant) {
    final local = instant.toUtc().add(Duration(minutes: offsetMinutesAt(instant)));
    return local.hour * 60 + local.minute;
  }
}
