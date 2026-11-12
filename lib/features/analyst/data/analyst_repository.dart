import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/analyst.dart';

/// Weekly reviews and the trader's sources, on this device.
///
/// TODO(backend): sync reviews with the account; upload source files to
/// Storage `sources/<uid>/<accountId>/<id>` under RLS (design/analyst-plan.md).
abstract interface class AnalystRepository {
  List<WeeklyReview> loadReviews();
  Future<void> saveReviews(List<WeeklyReview> reviews);
  List<AccountSource> loadSources();
  Future<void> saveSources(List<AccountSource> sources);
  Future<void> clear();
}

/// shared_preferences implementation; a record that fails to parse is skipped.
class PrefsAnalystRepository implements AnalystRepository {
  PrefsAnalystRepository(this._prefs);

  final SharedPreferences _prefs;

  static const reviewsKey = 'doji.review.v1';
  static const sourcesKey = 'doji.sources.v1';

  List<T> _load<T>(String key, T? Function(Object?) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final list = json is Map ? json['items'] : null;
      if (list is! List) return const [];
      return [for (final item in list) ?parse(item)];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(String key, List<Map<String, Object?>> items) =>
      _prefs.setString(key, jsonEncode({'version': 1, 'items': items}));

  @override
  List<WeeklyReview> loadReviews() => _load(reviewsKey, WeeklyReview.fromJson);

  @override
  Future<void> saveReviews(List<WeeklyReview> reviews) =>
      _save(reviewsKey, [for (final r in reviews) r.toJson()]);

  @override
  List<AccountSource> loadSources() => _load(sourcesKey, AccountSource.fromJson);

  @override
  Future<void> saveSources(List<AccountSource> sources) =>
      _save(sourcesKey, [for (final s in sources) s.toJson()]);

  @override
  Future<void> clear() async {
    await _prefs.remove(reviewsKey);
    await _prefs.remove(sourcesKey);
  }
}

final analystRepositoryProvider = Provider<AnalystRepository>(
  (ref) => PrefsAnalystRepository(ref.watch(sharedPreferencesProvider)),
);
