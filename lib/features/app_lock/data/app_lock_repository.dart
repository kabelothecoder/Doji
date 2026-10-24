import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart';

/// App lock preferences. Device-only: never synced to the account.
class AppLockRepository {
  const AppLockRepository(this._prefs);

  final SharedPreferences _prefs;

  static const enabledKey = 'doji.app_lock.enabled.v1';
  static const offeredKey = 'doji.app_lock.offered.v1';
  static const homeVisitsKey = 'doji.app_lock.home_visits.v1';

  bool get enabled => _prefs.getBool(enabledKey) ?? false;
  Future<void> setEnabled(bool v) => _prefs.setBool(enabledKey, v);

  /// A8a is offered once.
  bool get offered => _prefs.getBool(offeredKey) ?? false;
  Future<void> markOffered() => _prefs.setBool(offeredKey, true);

  int get homeVisits => _prefs.getInt(homeVisitsKey) ?? 0;
  Future<void> recordHomeVisit() => _prefs.setInt(homeVisitsKey, homeVisits + 1);

  Future<void> clear() async {
    await _prefs.remove(enabledKey);
    await _prefs.remove(offeredKey);
    await _prefs.remove(homeVisitsKey);
  }
}

final appLockRepositoryProvider = Provider<AppLockRepository>(
  (ref) => AppLockRepository(ref.watch(sharedPreferencesProvider)),
);
