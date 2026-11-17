import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/gym.dart';

enum GymEntryKind {
  /// One drill answer.
  drill,

  /// A finished daily drill set (feeds the streak and Home's practice days).
  drillSet,

  /// A finished replay practice with its process grade.
  practice;

  static GymEntryKind? fromName(String? n) => values.where((v) => v.name == n).firstOrNull;
}

/// One thing done in the gym: a drill answer, a finished set, a practice.
class GymEntry {
  const GymEntry({
    required this.id,
    required this.at,
    required this.accountId,
    required this.kind,
    this.drill,
    this.correct,
    this.answer,
    this.grade,
    this.symbol,
    this.notes = const [],
  });

  final String id;

  /// UTC.
  final DateTime at;
  final String accountId;
  final GymEntryKind kind;
  final DrillKind? drill;
  final bool? correct;

  /// The trader's answer as typed or tapped.
  final String? answer;

  /// Practice: the process grade letter.
  final String? grade;
  final String? symbol;

  /// Practice: the check lines; a set: "4 of 5".
  final List<String> notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'accountId': accountId,
    'kind': kind.name,
    'drill': drill?.name,
    'correct': correct,
    'answer': answer,
    'grade': grade,
    'symbol': symbol,
    'notes': notes,
  };

  static GymEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    final kind = GymEntryKind.fromName(j['kind'] as String?);
    if (j['id'] is! String || j['accountId'] is! String || at == null || kind == null) return null;
    return GymEntry(
      id: j['id'] as String,
      at: at.toUtc(),
      accountId: j['accountId'] as String,
      kind: kind,
      drill: DrillKind.fromName(j['drill'] as String?),
      correct: j['correct'] as bool?,
      answer: j['answer'] as String?,
      grade: j['grade'] as String?,
      symbol: j['symbol'] as String?,
      notes: [for (final n in (j['notes'] as List? ?? const [])) '$n'],
    );
  }

  /// What the AI analyst reads.
  Map<String, dynamic> toAnalystJson() => toJson()..remove('id');
}

/// Gym scores and drill answers.
///
/// TODO(next-slice): Supabase sync, as planned for the journal
/// (`journal_repository.dart`): a `gym_entries` table keyed by `id`, owned by
/// `auth.uid()`. Local stays the source until then.
abstract interface class GymRepository {
  List<GymEntry> load();
  Future<void> save(List<GymEntry> entries);
  Future<void> clear();
}

class PrefsGymRepository implements GymRepository {
  PrefsGymRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.gym.v1';

  @override
  List<GymEntry> load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['entries'] : null;
      if (list is! List) return const [];
      return [for (final e in list) ?GymEntry.fromJson(e)];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<GymEntry> entries) => _prefs.setString(
    key,
    jsonEncode({
      'version': 1,
      'entries': [for (final e in entries) e.toJson()],
    }),
  );

  @override
  Future<void> clear() => _prefs.remove(key);
}

final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => PrefsGymRepository(ref.watch(sharedPreferencesProvider)),
);

class GymController extends Notifier<List<GymEntry>> {
  static const keep = 2000;

  @override
  List<GymEntry> build() => ref.watch(gymRepositoryProvider).load();

  Future<void> add(GymEntry e) async {
    final next = [...state, e];
    state = next.length > keep ? next.sublist(next.length - keep) : next;
    await ref.read(gymRepositoryProvider).save(state);
  }
}

final gymProvider = NotifierProvider<GymController, List<GymEntry>>(GymController.new);

/// Local days with a finished drill set (any account): practice, never trading days.
final practiceDaysProvider = Provider<Set<DateTime>>((ref) {
  final days = <DateTime>{};
  for (final e in ref.watch(gymProvider)) {
    if (e.kind != GymEntryKind.drillSet) continue;
    final l = e.at.toLocal();
    days.add(DateTime(l.year, l.month, l.day));
  }
  return days;
});

final drillStreakProvider = Provider<int>((ref) => drillStreak(ref.watch(practiceDaysProvider), clock.now()));
