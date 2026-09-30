import 'package:doji_app/core/haptics/doji_haptics.dart';
import 'package:doji_app/core/platform/connectivity.dart';
import 'package:doji_app/features/onboarding/data/device_services.dart';
import 'package:doji_app/features/onboarding/data/mock_strategy_parser.dart';
import 'package:doji_app/features/onboarding/data/onboarding_repository.dart';
import 'package:doji_app/features/onboarding/data/voice_input.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTimeZoneService implements TimeZoneService {
  const FakeTimeZoneService({this.id = 'Africa/Johannesburg', this.offsetMinutes = 120});

  final String id;
  final int offsetMinutes;

  @override
  Future<DetectedTimeZone> detect() async => DetectedTimeZone(id: id, offsetMinutes: offsetMinutes);
}

class FakeNotificationPermission implements NotificationPermission {
  FakeNotificationPermission([this.result = NotificationPermissionResult.granted]);

  final NotificationPermissionResult result;
  int requests = 0;

  @override
  Future<NotificationPermissionResult> request() async {
    requests++;
    return result;
  }
}

class RecordingHaptics extends DojiHaptics {
  RecordingHaptics();

  final events = <String>[];

  @override
  Future<void> tick() async => events.add('tick');

  @override
  Future<void> light() async => events.add('light');

  @override
  Future<void> heavy() async => events.add('heavy');
}

/// Everything platform-specific replaced with deterministic fakes.
List<Override> testOverrides(SharedPreferences prefs, {RecordingHaptics? haptics}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  timeZoneServiceProvider.overrideWithValue(const FakeTimeZoneService()),
  strategyParserProvider.overrideWithValue(const MockStrategyParser(latency: Duration.zero)),
  notificationPermissionProvider.overrideWithValue(FakeNotificationPermission()),
  voiceInputProvider.overrideWithValue(const UnavailableVoiceInput()),
  isOnlineProvider.overrideWith((ref) => Stream.value(true)),
  hapticsProvider.overrideWithValue(haptics ?? RecordingHaptics()),
];
