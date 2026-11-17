import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../journal/domain/trade.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/mood.dart';

/// Mood entries on this device (`doji.mood.v1`), newest first.
///
/// TODO(backend): sync to a `mood_entries` table owned by `auth.uid()`, pushed on sign-in like the journal.
class MoodRepository {
  MoodRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.mood.v1';
  static const version = 1;

  List<MoodEntry> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['entries'] : null;
      if (list is! List) return const [];
      // A record that fails to parse is skipped; the rest stay.
      return [for (final item in list) ?MoodEntry.fromJson(item)]..sort((a, b) => b.time.compareTo(a.time));
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<MoodEntry> entries) => _prefs.setString(
    key,
    jsonEncode({
      'version': version,
      'entries': [for (final e in entries) e.toJson()],
    }),
  );

  Future<void> clear() => _prefs.remove(key);
}

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(ref.watch(sharedPreferencesProvider)),
);

/// Every entry on the device, newest first.
class MoodController extends Notifier<List<MoodEntry>> {
  @override
  List<MoodEntry> build() => ref.read(moodRepositoryProvider).load();

  /// Logs [feeling] against the active account (and [tradeId] when given).
  Future<MoodEntry> log({
    required String feeling,
    required MoodMoment moment,
    int? intensity,
    String note = '',
    String? tradeId,
  }) async {
    final entry = MoodEntry(
      id: const Uuid().v4(),
      feeling: feeling,
      intensity: intensity,
      note: note.trim(),
      time: clock.now(),
      accountId: ref.read(onboardingRepositoryProvider).loadProfile()?.activeAccount?.id,
      tradeId: tradeId,
      moment: moment,
    );
    state = [entry, ...state];
    await ref.read(moodRepositoryProvider).save(state);
    return entry;
  }
}

final moodControllerProvider = NotifierProvider<MoodController, List<MoodEntry>>(MoodController.new);

/// The active account's entries, plus any logged before accounts existed.
final activeMoodProvider = Provider.autoDispose<List<MoodEntry>>((ref) {
  final id = ref.watch(journalProfileProvider.select((p) => p.activeAccount?.id));
  return [
    for (final e in ref.watch(moodControllerProvider))
      if (e.accountId == null || e.accountId == id) e,
  ];
});

/// Trends over the active account's entries and trades.
final moodTrendsProvider = Provider.autoDispose<MoodTrends>(
  (ref) => MoodTrends.of(ref.watch(activeMoodProvider), ref.watch(activeAccountTradesProvider), clock.now()),
);

/// The trade a mood logged now belongs to: the active account's newest trade
/// opened today, if any. Shortcut: today's newest, until the post-trade sheet is
/// opened from a specific trade (the imported trade slice).
String? latestTradeToday(List<Trade> trades, DateTime now) {
  Trade? best;
  for (final t in trades) {
    final o = t.openedAt.toLocal();
    if (o.year != now.year || o.month != now.month || o.day != now.day) continue;
    if (best == null || t.openedAt.isAfter(best.openedAt)) best = t;
  }
  return best?.id;
}
