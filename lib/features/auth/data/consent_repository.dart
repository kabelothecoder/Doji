import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../onboarding/data/onboarding_repository.dart' show sharedPreferencesProvider;

/// Bump when the terms or the privacy policy change: everyone is asked again.
const int kConsentVersion = 1;

/// A7 "18+ and consent" on this device. A new account is marked pending right
/// after its first sign-in, so closing the app on A7 brings A7 back at launch.
///
/// TODO(backend): record the consent (user id, version, time) on the account
/// in Supabase too, and read it back so a new device skips A7.
class ConsentRepository {
  ConsentRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.consent.v1';

  Map<String, Object?> _read() {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return {};
    }
  }

  /// The user still has to agree (new account, or terms changed since).
  bool needsConsent(String userId) {
    final r = _read();
    if (r['userId'] != userId) return false;
    return r['pending'] == true || (r['version'] as int? ?? 0) < kConsentVersion;
  }

  /// Agreed to the current terms on this device.
  bool accepted(String userId) {
    final r = _read();
    return r['userId'] == userId && r['pending'] != true && (r['version'] as int? ?? 0) >= kConsentVersion;
  }

  /// The intent the pending sign-in started with ("save" or "signIn").
  String? pendingIntent(String userId) {
    final r = _read();
    return r['userId'] == userId && r['pending'] == true ? r['intent'] as String? : null;
  }

  Future<void> markPending(String userId, String intent) =>
      _prefs.setString(key, jsonEncode({'userId': userId, 'pending': true, 'intent': intent}));

  Future<void> accept(String userId) => _prefs.setString(
    key,
    jsonEncode({
      'userId': userId,
      'pending': false,
      'version': kConsentVersion,
      'at': clock.now().toUtc().toIso8601String(),
    }),
  );

  Future<void> clear() => _prefs.remove(key);
}

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(ref.watch(sharedPreferencesProvider)),
);
