import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';
import '../domain/brief_allowance.dart';

/// Today's free brief, on this device (`doji.brief.v1`).
class BriefAllowanceRepository {
  const BriefAllowanceRepository(this._prefs);

  static const key = 'doji.brief.v1';

  final SharedPreferences _prefs;

  BriefAllowance load() {
    final raw = _prefs.getString(key);
    if (raw == null) return const BriefAllowance();
    try {
      return BriefAllowance.fromJson(jsonDecode(raw));
    } on FormatException {
      return const BriefAllowance();
    }
  }

  Future<void> save(BriefAllowance allowance) => _prefs.setString(key, jsonEncode(allowance.toJson()));

  /// Sign out and delete wipe local data.
  Future<void> clear() => _prefs.remove(key);
}

final briefAllowanceRepositoryProvider = Provider<BriefAllowanceRepository>(
  (ref) => BriefAllowanceRepository(ref.watch(sharedPreferencesProvider)),
);
