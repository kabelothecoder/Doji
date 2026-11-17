import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../journal/presentation/journal_controller.dart';
import '../../mood/data/mood_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/mind_catalog.dart';
import '../domain/scorecard.dart';

/// A saved answer to a reflection prompt.
class PromptAnswer {
  const PromptAnswer(this.promptId, this.text, this.at);

  final String promptId;
  final String text;
  final DateTime at;
}

/// What the trader keeps in the toolkit: favourite affirmations, their own affirmations, read
/// reading cards, prompt answers (newest first).
class MindState {
  const MindState({
    this.favourites = const {},
    this.own = const [],
    this.read = const {},
    this.answers = const [],
  });

  final Set<String> favourites;
  final List<Affirmation> own;
  final Set<String> read;
  final List<PromptAnswer> answers;

  MindState copyWith({
    Set<String>? favourites,
    List<Affirmation>? own,
    Set<String>? read,
    List<PromptAnswer>? answers,
  }) => MindState(
    favourites: favourites ?? this.favourites,
    own: own ?? this.own,
    read: read ?? this.read,
    answers: answers ?? this.answers,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'favourites': favourites.toList(),
    'own': [
      for (final a in own) {'id': a.id, 'text': a.text},
    ],
    'read': read.toList(),
    'answers': [
      for (final a in answers) {'promptId': a.promptId, 'text': a.text, 'at': a.at.toUtc().toIso8601String()},
    ],
  };

  /// Anything that fails to parse is skipped, never fatal.
  static MindState fromJson(Object? json) {
    if (json is! Map) return const MindState();
    List<Object?> list(String k) => json[k] is List ? json[k] as List : const [];
    return MindState(
      favourites: {
        for (final f in list('favourites'))
          if (f is String) f,
      },
      read: {
        for (final r in list('read'))
          if (r is String) r,
      },
      own: [
        for (final o in list('own'))
          if (o is Map && o['id'] is String && o['text'] is String)
            Affirmation(o['id'] as String, o['text'] as String, own: true),
      ],
      answers: [
        for (final a in list('answers'))
          if (a is Map &&
              a['promptId'] is String &&
              a['text'] is String &&
              DateTime.tryParse('${a['at']}') != null)
            PromptAnswer(a['promptId'] as String, a['text'] as String, DateTime.parse('${a['at']}')),
      ],
    );
  }
}

/// TODO(backend): sync favourites, own affirmations, read state and answers to the account.
class MindRepository {
  MindRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.mind.v1';

  MindState load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const MindState();
    try {
      return MindState.fromJson(jsonDecode(raw));
    } on FormatException {
      return const MindState();
    }
  }

  Future<void> save(MindState s) => _prefs.setString(key, jsonEncode(s.toJson()));

  Future<void> clear() => _prefs.remove(key);
}

final mindRepositoryProvider = Provider<MindRepository>(
  (ref) => MindRepository(ref.watch(sharedPreferencesProvider)),
);

class MindController extends Notifier<MindState> {
  @override
  MindState build() => ref.watch(mindRepositoryProvider).load();

  void _set(MindState s) {
    state = s;
    ref.read(mindRepositoryProvider).save(s).ignore();
  }

  void toggleFavourite(String id) {
    final f = {...state.favourites};
    if (!f.remove(id)) f.add(id);
    _set(state.copyWith(favourites: f));
  }

  void addOwn(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final id = 'own-${clock.now().microsecondsSinceEpoch}';
    _set(state.copyWith(own: [Affirmation(id, t, own: true), ...state.own]));
  }

  void deleteOwn(String id) => _set(
    state.copyWith(
      own: [
        for (final a in state.own)
          if (a.id != id) a,
      ],
      favourites: {...state.favourites}..remove(id),
    ),
  );

  void markRead(String id) {
    if (state.read.contains(id)) return;
    _set(state.copyWith(read: {...state.read, id}));
  }

  void answer(String promptId, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _set(state.copyWith(answers: [PromptAnswer(promptId, t, clock.now()), ...state.answers]));
  }
}

final mindControllerProvider = NotifierProvider<MindController, MindState>(MindController.new);

/// This week's scorecard on the active account.
final scorecardProvider = Provider.autoDispose<Scorecard>(
  (ref) => Scorecard.of(
    trades: ref.watch(activeAccountTradesProvider),
    account: ref.watch(journalProfileProvider).activeAccount,
    moods: ref.watch(activeMoodProvider),
    now: clock.now(),
  ),
);
