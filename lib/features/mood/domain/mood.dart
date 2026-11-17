import '../../journal/domain/trade.dart';

/// The feelings doji offers: The Open's moods plus the journal's emotions,
/// one list so every place counts the same words.
const List<String> kMoodFeelings = [
  'calm',
  'focused',
  'confident',
  'patient',
  'tired',
  'anxious',
  'restless',
  'frustrated',
  'angry',
  'bored',
];

/// Under this many entries a count is "small sample".
const int kMoodSmallSample = 5;

/// How close to a losing trade an entry must be to count as before or after it.
const Duration kMoodLossWindow = Duration(minutes: 60);

/// Where an entry was logged.
enum MoodMoment {
  /// The mood screen's check-in.
  checkIn('check-in'),

  /// The Open's mood step.
  open('the open'),

  /// The post-trade sheet or the rail, "before the trade".
  beforeTrade('before a trade'),

  /// The post-trade sheet or the rail, "after the trade".
  afterTrade('after a trade');

  const MoodMoment(this.label);

  final String label;
}

/// One logged feeling. [intensity] is 1–10, null where nothing asked for one
/// (The Open picks a mood only). [tradeId] links it to a trade when there is one.
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.feeling,
    required this.time,
    this.intensity,
    this.note = '',
    this.accountId,
    this.tradeId,
    this.moment = MoodMoment.checkIn,
  });

  final String id;
  final String feeling;
  final int? intensity;
  final String note;
  final DateTime time;
  final String? accountId;
  final String? tradeId;
  final MoodMoment moment;

  Map<String, Object?> toJson() => {
    'id': id,
    'feeling': feeling,
    'intensity': ?intensity,
    if (note.isNotEmpty) 'note': note,
    'time': time.toUtc().toIso8601String(),
    'accountId': ?accountId,
    'tradeId': ?tradeId,
    'moment': moment.name,
  };

  /// Null when the record is not an entry (skipped, never fatal).
  static MoodEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], feeling = json['feeling'];
    final time = DateTime.tryParse('${json['time']}');
    if (id is! String || feeling is! String || time == null) return null;
    final intensity = json['intensity'];
    return MoodEntry(
      id: id,
      feeling: feeling,
      time: time,
      intensity: intensity is num ? intensity.toInt().clamp(1, 10) : null,
      note: json['note'] is String ? json['note'] as String : '',
      accountId: json['accountId'] is String ? json['accountId'] as String : null,
      tradeId: json['tradeId'] is String ? json['tradeId'] as String : null,
      moment: MoodMoment.values.asNameMap()[json['moment']] ?? MoodMoment.checkIn,
    );
  }
}

/// Counts per feeling, most first (ties keep [kMoodFeelings] order).
class FeelingCounts {
  FeelingCounts(Iterable<MoodEntry> entries) : total = entries.length, counts = _count(entries);

  final int total;
  final List<(String, int)> counts;

  bool get smallSample => total < kMoodSmallSample;

  static List<(String, int)> _count(Iterable<MoodEntry> entries) {
    final m = <String, int>{};
    for (final e in entries) {
      m[e.feeling] = (m[e.feeling] ?? 0) + 1;
    }
    int rank(String f) {
      final i = kMoodFeelings.indexOf(f);
      return i < 0 ? kMoodFeelings.length : i;
    }

    return m.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$2 != b.$2 ? b.$2 - a.$2 : rank(a.$1) - rank(b.$1));
  }
}

/// Mood trends: what was felt over the last 7 and 28 days, and around losing
/// trades. Before a loss = logged in the hour before a losing trade opened;
/// after = in the hour after one closed. Counts, never a judgement.
class MoodTrends {
  const MoodTrends({
    required this.week,
    required this.month,
    required this.beforeLoss,
    required this.afterLoss,
  });

  final FeelingCounts week;
  final FeelingCounts month;
  final FeelingCounts beforeLoss;
  final FeelingCounts afterLoss;

  factory MoodTrends.of(List<MoodEntry> entries, List<Trade> trades, DateTime now) {
    bool within(MoodEntry e, int days) =>
        !e.time.isAfter(now) && now.difference(e.time) < Duration(days: days);
    final losses = trades.where((t) => t.isLoss).toList();
    bool before(MoodEntry e) => losses.any((t) {
      final d = t.openedAt.difference(e.time);
      return !d.isNegative && d <= kMoodLossWindow;
    });
    bool after(MoodEntry e) => losses.any((t) {
      final d = e.time.difference(t.closedAt);
      return !d.isNegative && d <= kMoodLossWindow;
    });
    final month = entries.where((e) => within(e, 28)).toList();
    return MoodTrends(
      week: FeelingCounts(entries.where((e) => within(e, 7))),
      month: FeelingCounts(month),
      beforeLoss: FeelingCounts(month.where(before)),
      afterLoss: FeelingCounts(month.where(after)),
    );
  }
}
