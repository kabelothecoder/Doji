import 'time_zones.dart';

/// When an instrument trades. Market-neutral: crypto and synthetic indices
/// are always open; forex, CFDs, futures and stocks have weekly windows in
/// their exchange's real time zone, so daylight saving moves them correctly.
///
/// Not modelled: exchange holidays and a broker's own daily breaks.
class MarketHours {
  const MarketHours.always() : alwaysOpen = true, windows = const [], timeZone = null;

  /// [windows] are wall-clock times in [timeZone] (an IANA id).
  const MarketHours.weekly(this.windows, {required String this.timeZone}) : alwaysOpen = false;

  final bool alwaysOpen;
  final List<WeeklyWindow> windows;
  final String? timeZone;

  /// Forex and broker CFDs: the FX week runs Sunday 17:00 to Friday 17:00
  /// New York time (22:00 UTC in winter, 21:00 UTC in summer).
  static const forexWeek = MarketHours.weekly([
    WeeklyWindow.span(fromDay: DateTime.sunday, fromHour: 17, toDay: DateTime.friday, toHour: 17),
  ], timeZone: TimeZones.newYork);

  /// CME Globex: Sunday 17:00 to Friday 16:00 Chicago time.
  static const futuresWeek = MarketHours.weekly([
    WeeklyWindow.span(fromDay: DateTime.sunday, fromHour: 17, toDay: DateTime.friday, toHour: 16),
  ], timeZone: TimeZones.chicago);

  /// US regular session, 09:30–16:00 New York time.
  static const usStocks = MarketHours.weekly([
    WeeklyWindow.span(
      fromDay: DateTime.monday,
      fromHour: 9,
      fromMinute: 30,
      toDay: DateTime.monday,
      toHour: 16,
    ),
    WeeklyWindow.span(
      fromDay: DateTime.tuesday,
      fromHour: 9,
      fromMinute: 30,
      toDay: DateTime.tuesday,
      toHour: 16,
    ),
    WeeklyWindow.span(
      fromDay: DateTime.wednesday,
      fromHour: 9,
      fromMinute: 30,
      toDay: DateTime.wednesday,
      toHour: 16,
    ),
    WeeklyWindow.span(
      fromDay: DateTime.thursday,
      fromHour: 9,
      fromMinute: 30,
      toDay: DateTime.thursday,
      toHour: 16,
    ),
    WeeklyWindow.span(
      fromDay: DateTime.friday,
      fromHour: 9,
      fromMinute: 30,
      toDay: DateTime.friday,
      toHour: 16,
    ),
  ], timeZone: TimeZones.newYork);

  /// Is the market open at the instant [utc]?
  bool isOpenAt(DateTime utc) {
    if (alwaysOpen) return true;
    final location = TimeZones.find(timeZone!);
    // An unknown zone id is a catalogue bug; say "open" rather than block the user.
    if (location == null) return true;
    final local = TimeZones.inZone(utc, location);
    final minute = WeeklyWindow.at(local.weekday, local.hour, local.minute);
    return windows.any((w) => w.contains(minute));
  }
}

/// A window inside the week, in local wall-clock minutes since Monday 00:00.
/// When [start] is after [end] it wraps over the week boundary.
class WeeklyWindow {
  const WeeklyWindow({required this.start, required this.end});

  /// From a weekday and time to a weekday and time (Monday = 1 … Sunday = 7).
  const WeeklyWindow.span({
    required int fromDay,
    required int fromHour,
    int fromMinute = 0,
    required int toDay,
    required int toHour,
    int toMinute = 0,
  }) : start = (fromDay - 1) * minutesPerDay + fromHour * 60 + fromMinute,
       end = (toDay - 1) * minutesPerDay + toHour * 60 + toMinute;

  final int start;
  final int end;

  static const int minutesPerDay = 24 * 60;

  /// Minute of the week for a [DateTime] weekday, hour and minute.
  static int at(int weekday, int hour, [int minute = 0]) =>
      (weekday - 1) * minutesPerDay + hour * 60 + minute;

  bool contains(int minuteOfWeek) => start <= end
      ? minuteOfWeek >= start && minuteOfWeek < end
      : minuteOfWeek >= start || minuteOfWeek < end;
}
