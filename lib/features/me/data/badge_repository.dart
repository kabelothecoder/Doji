import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../gym/data/gym_repository.dart';
import '../../journal/presentation/journal_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/me.dart';

/// Earned badges (id → when), so a badge stays earned once reached.
///
/// TODO(backend): for sync: a `badges` table owned by `auth.uid()`, pushed on sign-in.
class BadgeRepository {
  BadgeRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.badges.v1';

  Map<String, DateTime> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw);
      final m = json is Map ? json['earned'] : null;
      if (m is! Map) return const {};
      return {
        for (final e in m.entries)
          if (e.value is String && DateTime.tryParse(e.value as String) != null)
            e.key as String: DateTime.parse(e.value as String),
      };
    } on FormatException {
      return const {};
    }
  }

  Future<void> save(Map<String, DateTime> earned) => _prefs.setString(
    key,
    jsonEncode({
      'version': 1,
      'earned': {for (final e in earned.entries) e.key: e.value.toUtc().toIso8601String()},
    }),
  );

  Future<void> clear() => _prefs.remove(key);
}

final badgeRepositoryProvider = Provider<BadgeRepository>(
  (ref) => BadgeRepository(ref.watch(sharedPreferencesProvider)),
);

/// Stored badges plus any the journal and gym earn now; new ones are saved.
final earnedBadgesProvider = Provider<Map<String, DateTime>>((ref) {
  final repo = ref.watch(badgeRepositoryProvider);
  final stored = repo.load();
  final now = clock.now();
  final fresh = {
    for (final id in earnedBadgeIds(ref.watch(journalControllerProvider), ref.watch(practiceDaysProvider)))
      if (!stored.containsKey(id)) id: now,
  };
  if (fresh.isEmpty) return stored;
  final all = {...stored, ...fresh};
  repo.save(all).ignore();
  return all;
});

final badgesProvider = Provider<List<MeBadge>>(
  (ref) => badgesFor(
    ref.watch(journalControllerProvider),
    ref.watch(practiceDaysProvider),
    ref.watch(earnedBadgesProvider).keys.toSet(),
  ),
);

/// Kept days by local date: the one source for Home's MiniGrid and the year grid.
final keptDaysProvider = Provider<Map<DateTime, bool>>(
  (ref) => keptDays(ref.watch(journalControllerProvider)),
);
