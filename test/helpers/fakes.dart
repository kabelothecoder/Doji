import 'package:doji_app/core/haptics/doji_haptics.dart';
import 'package:doji_app/core/platform/connectivity.dart';
import 'package:doji_app/features/app_lock/data/biometric_auth.dart';
import 'package:doji_app/features/app_lock/domain/biometric_kind.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
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
  Future<void> success() async => events.add('success');

  @override
  Future<void> heavy() async => events.add('heavy');
}

/// Face ID that answers [result] (or [results] in order) without a prompt.
class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({
    this.kind = BiometricKind.faceId,
    this.result = BiometricResult.success,
    List<BiometricResult>? results,
  }) : _queue = [...?results];

  BiometricKind? kind;
  BiometricResult result;
  final List<BiometricResult> _queue;
  final calls = <({String reason, bool allowFallback})>[];

  @override
  Future<BiometricKind?> availableKind() async => kind;

  @override
  Future<BiometricResult> authenticate({required String reason, bool allowFallback = false}) async {
    calls.add((reason: reason, allowFallback: allowFallback));
    return _queue.isNotEmpty ? _queue.removeAt(0) : result;
  }
}

/// [FakeAuthRepository] with test latencies (short, but long enough to see
/// the waiting states).
FakeAuthRepository testAuthRepository(SharedPreferences prefs, {bool Function()? isOnline}) =>
    FakeAuthRepository(
      prefs,
      isOnline: isOnline,
      sheetLatency: const Duration(milliseconds: 100),
      networkLatency: const Duration(milliseconds: 50),
    );

/// Everything platform-specific replaced with deterministic fakes.
List<Override> testOverrides(
  SharedPreferences prefs, {
  RecordingHaptics? haptics,
  FakeBiometricAuth? biometric,
  bool Function()? isOnline,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  timeZoneServiceProvider.overrideWithValue(const FakeTimeZoneService()),
  strategyParserProvider.overrideWithValue(const MockStrategyParser(latency: Duration.zero)),
  notificationPermissionProvider.overrideWithValue(FakeNotificationPermission()),
  voiceInputProvider.overrideWithValue(const UnavailableVoiceInput()),
  isOnlineProvider.overrideWith((ref) => Stream.value(true)),
  hapticsProvider.overrideWithValue(haptics ?? RecordingHaptics()),
  biometricAuthProvider.overrideWithValue(biometric ?? FakeBiometricAuth()),
  authRepositoryProvider.overrideWithValue(testAuthRepository(prefs, isOnline: isOnline)),
];
