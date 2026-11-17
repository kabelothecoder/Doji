import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../journal/domain/formatting.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../plans/domain/plans.dart';

/// Pro trader's voice minutes a month.
const int kProVoiceMinutes = 60;

/// Voice minutes left this month on [plan], or null when the plan does not
/// count them (elite prop: fair use; free and basic: no voice coach).
int? voiceMinutesLeft(PlanId plan, int usedSeconds) => plan == PlanId.pro
    ? ((kProVoiceMinutes * 60 - usedSeconds) / 60).floor().clamp(0, kProVoiceMinutes)
    : null;

/// When the minutes come back: the first of next month ("1 dec").
String voiceMinutesResetOn(DateTime now) => '1 ${monthShort(now.month == 12 ? 1 : now.month + 1)}';

/// Voice seconds used this month on this device (`doji.voice_minutes.v1`).
/// Only the time the mic is open counts: the coach has no audio yet.
///
/// TODO(backend): server metering. The `ai-coach` function should count minutes per user per month
/// and be the source of truth; this device count is a stand-in and resets with the app's data.
class VoiceMinutesRepository {
  VoiceMinutesRepository(this._prefs);

  final SharedPreferences _prefs;

  static const key = 'doji.voice_minutes.v1';

  static String _month(DateTime now) => '${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// Seconds used in [now]'s month; another month's count reads as 0.
  int usedSeconds(DateTime now) {
    final raw = _prefs.getString(key);
    if (raw == null) return 0;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['month'] != _month(now)) return 0;
      final s = json['seconds'];
      return s is num ? s.toInt() : 0;
    } on FormatException {
      return 0;
    }
  }

  /// Adds [used] to [now]'s month and returns the new total.
  Future<int> add(Duration used, DateTime now) async {
    final total = usedSeconds(now) + used.inSeconds;
    await _prefs.setString(key, jsonEncode({'version': 1, 'month': _month(now), 'seconds': total}));
    return total;
  }

  Future<void> clear() => _prefs.remove(key);
}

final voiceMinutesRepositoryProvider = Provider<VoiceMinutesRepository>(
  (ref) => VoiceMinutesRepository(ref.watch(sharedPreferencesProvider)),
);
