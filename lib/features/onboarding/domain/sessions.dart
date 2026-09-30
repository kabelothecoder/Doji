/// Trading sessions and their opens, in minutes after 00:00 UTC.
///
/// APPROXIMATION: fixed UTC opens (Tokyo 09:00 JST, London 08:00 BST,
/// New York 08:00 EDT). DST shifts are not modelled yet; the handoff example
/// (London 09:00 at UTC+2) matches. TODO(next-slice): use a tz database.
enum TradingSession {
  asia('asia', 'Asia', 0),
  london('london', 'London', 7 * 60),
  newYork('new_york', 'New York', 12 * 60),
  aroundJob('around_job', 'around my job', null);

  const TradingSession(this.key, this.label, this.openUtcMinutes);

  final String key;
  final String label;
  final int? openUtcMinutes;

  static TradingSession? fromKey(String key) => TradingSession.values.where((s) => s.key == key).firstOrNull;

  /// Local minutes after midnight for [offsetMinutes] (UTC offset).
  int? localOpen(int offsetMinutes) =>
      openUtcMinutes == null ? null : (openUtcMinutes! + offsetMinutes) % (24 * 60);
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

/// The session whose open comes first in the user's local day, ignoring
/// "around my job" (it has no fixed open).
TradingSession? firstSession(List<String> keys, int offsetMinutes) {
  final fixed =
      keys
          .map(TradingSession.fromKey)
          .whereType<TradingSession>()
          .where((s) => s.openUtcMinutes != null)
          .toList()
        ..sort((a, b) => a.localOpen(offsetMinutes)!.compareTo(b.localOpen(offsetMinutes)!));
  return fixed.firstOrNull;
}

/// Reference time for The Open: the first session's local open, or 08:00
/// local when the user only trades around their job.
int openReferenceMinutes(List<String> keys, int offsetMinutes) =>
    firstSession(keys, offsetMinutes)?.localOpen(offsetMinutes) ?? 8 * 60;
