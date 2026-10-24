import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/trade.dart';

/// Where the journal's trades live. The UI only sees this interface.
///
/// TODO(next-slice): Supabase sync. Add a `journal_trades` table (one row per
/// trade, keyed by `id`, owned by `auth.uid()`), push local trades when the
/// user signs in, and pull theirs on a new device. Local stays the source
/// until then, exactly like profile.doji ("welcome back" → the account's,
/// "save your setup" → this device's).
abstract interface class JournalRepository {
  List<Trade> load();
  Future<void> save(List<Trade> trades);
  Future<void> clear();
}

/// shared_preferences implementation. Reads are synchronous (the instance is
/// created once in bootstrap), so the journal opens without a loading state.
class PrefsJournalRepository implements JournalRepository {
  PrefsJournalRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.journal.v1';
  static const version = 1;

  @override
  List<Trade> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['trades'] : null;
      if (list is! List) return const [];
      // A record that fails to parse is skipped; the rest of the journal stays.
      return [for (final item in list) ?Trade.fromJson(item)];
    } on FormatException {
      return const []; // corrupt: start empty rather than crash the tab
    }
  }

  @override
  Future<void> save(List<Trade> trades) => _prefs.setString(
    key,
    jsonEncode({
      'version': version,
      'trades': [for (final t in trades) t.toJson()],
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);
}

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => PrefsJournalRepository(ref.watch(sharedPreferencesProvider)),
);
