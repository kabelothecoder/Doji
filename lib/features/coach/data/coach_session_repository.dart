import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/coach_session.dart';

/// Where saved coach sessions live. The UI only sees this interface.
///
/// TODO(next-slice): Supabase sync (a `coach_sessions` table owned by
/// `auth.uid()`, pushed on sign-in like the journal), and a place in the
/// journal to read saved sessions back.
abstract interface class CoachSessionRepository {
  /// Newest first.
  List<CoachSession> load();

  /// Adds [session], or replaces the saved one with the same id.
  Future<void> save(CoachSession session);

  Future<void> clear();
}

/// shared_preferences implementation, like the journal.
class PrefsCoachSessionRepository implements CoachSessionRepository {
  PrefsCoachSessionRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.coach.v1';
  static const version = 1;

  @override
  List<CoachSession> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['sessions'] : null;
      if (list is! List) return const [];
      // A record that fails to parse is skipped; the rest stay.
      return [for (final item in list) ?CoachSession.fromJson(item)];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(CoachSession session) {
    final sessions = [session, ...load().where((s) => s.id != session.id)];
    return _prefs.setString(
      key,
      jsonEncode({
        'version': version,
        'sessions': [for (final s in sessions) s.toJson()],
      }),
    );
  }

  @override
  Future<void> clear() => _prefs.remove(key);
}

final coachSessionRepositoryProvider = Provider<CoachSessionRepository>(
  (ref) => PrefsCoachSessionRepository(ref.watch(sharedPreferencesProvider)),
);

/// Saved sessions, newest first (coach history in the me tab).
final savedCoachSessionsProvider = Provider.autoDispose<List<CoachSession>>(
  (ref) => ref.watch(coachSessionRepositoryProvider).load(),
);
