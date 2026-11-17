import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/chart_note.dart';

/// Where chart notes live. The UI only sees this interface.
///
/// TODO(next-slice): Supabase sync. Add a `chart_notes` table (one row per
/// note, keyed by `id`, owned by `auth.uid()`), push local notes when the
/// user signs in, and pull theirs on a new device. Local stays the source
/// until then, exactly like the journal (journal_repository.dart).
abstract interface class ChartNoteRepository {
  List<ChartNote> load();
  Future<void> save(List<ChartNote> notes);
  Future<void> clear();
}

/// shared_preferences implementation; a record that fails to parse is skipped.
class PrefsChartNoteRepository implements ChartNoteRepository {
  PrefsChartNoteRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.chartnotes.v1';
  static const version = 1;

  @override
  List<ChartNote> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['notes'] : null;
      if (list is! List) return const [];
      return [for (final item in list) ?ChartNote.fromJson(item)];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<ChartNote> notes) => _prefs.setString(
    key,
    jsonEncode({
      'version': version,
      'notes': [for (final n in notes) n.toJson()],
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);
}

final chartNoteRepositoryProvider = Provider<ChartNoteRepository>(
  (ref) => PrefsChartNoteRepository(ref.watch(sharedPreferencesProvider)),
);

/// Every chart note on this device, all accounts. Saved after every change.
class ChartNotesController extends Notifier<List<ChartNote>> {
  @override
  List<ChartNote> build() => ref.watch(chartNoteRepositoryProvider).load();

  ChartNote? byId(String id) => state.where((n) => n.id == id).firstOrNull;

  Future<void> upsert(ChartNote note) {
    final i = state.indexWhere((n) => n.id == note.id);
    return _set(i < 0 ? [...state, note] : ([...state]..[i] = note));
  }

  /// Applies [change] to the note [id], if there is one.
  Future<void> update(String id, ChartNote Function(ChartNote n) change) async {
    final n = byId(id);
    if (n != null) await upsert(change(n));
  }

  /// Links the notes that led to a trade (see [notesLeadingTo]).
  Future<void> linkTrade({
    required String tradeId,
    required String? accountId,
    required String symbol,
    required DateTime openedAt,
  }) async {
    final ids = notesLeadingTo(
      state,
      accountId: accountId,
      symbol: symbol,
      openedAt: openedAt,
    ).map((n) => n.id).toSet();
    if (ids.isEmpty) return;
    await _set([for (final n in state) ids.contains(n.id) ? n.copyWith(tradeId: () => tradeId) : n]);
  }

  Future<void> _set(List<ChartNote> next) {
    state = next;
    return ref.read(chartNoteRepositoryProvider).save(next);
  }
}

final chartNotesProvider = NotifierProvider<ChartNotesController, List<ChartNote>>(ChartNotesController.new);
