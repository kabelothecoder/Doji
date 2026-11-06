import 'package:doji_app/core/haptics/doji_haptics.dart';
import 'package:doji_app/core/platform/connectivity.dart';
import 'package:doji_app/core/platform/reminders.dart';
import 'package:doji_app/features/app_lock/data/biometric_auth.dart';
import 'package:doji_app/features/app_lock/domain/biometric_kind.dart';
import 'package:doji_app/features/auth/data/fake_auth_repository.dart';
import 'package:doji_app/features/coach/data/fake_coach.dart';
import 'package:doji_app/features/markets/data/fake_brief.dart';
import 'package:doji_app/features/markets/data/fake_brief_chat.dart';
import 'package:doji_app/features/markets/data/fake_market_data.dart';
import 'package:doji_app/features/markets/data/placeholder_rate_source.dart';
import 'package:doji_app/features/markets/data/live_rate_source.dart';
import 'package:doji_app/features/markets/data/routed_market_data.dart';
import 'package:doji_app/features/markets/data/sample_news_calendar.dart';
import 'package:doji_app/features/markets/domain/market_data.dart';
import 'package:doji_app/features/onboarding/data/device_services.dart';
import 'package:doji_app/features/onboarding/data/mock_strategy_parser.dart';
import 'package:doji_app/features/onboarding/domain/strategy_parser.dart';
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

/// Dictation the test drives: [say] what the mic hears, [silence] to end it
/// the way a pause does. [availability] answers the first `prepare`.
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput({this.availability = VoiceAvailability.available});

  final VoiceAvailability availability;
  int prepares = 0;
  int starts = 0;
  int stops = 0;
  void Function(String words, bool isFinal)? _onResult;
  void Function()? _onStopped;

  bool get listening => _onResult != null;

  @override
  bool get mightBeAvailable => true;

  @override
  Future<VoiceAvailability> prepare() async {
    prepares++;
    return availability;
  }

  @override
  Future<void> start({
    required void Function(String words, bool isFinal) onResult,
    required void Function() onStopped,
  }) async {
    starts++;
    _onResult = onResult;
    _onStopped = onStopped;
  }

  @override
  Future<void> stop() async {
    if (_onResult != null) stops++;
    _onResult = null;
    _onStopped = null;
  }

  void say(String words) => _onResult?.call(words, false);

  void silence() {
    final stopped = _onStopped;
    _onResult = null;
    _onStopped = null;
    stopped?.call();
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
  VoiceInput? voice,
  Reminders? reminders,
  MarketData? market,
  StrategyParser? parser,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  timeZoneServiceProvider.overrideWithValue(const FakeTimeZoneService()),
  strategyParserProvider.overrideWithValue(parser ?? const MockStrategyParser(latency: Duration.zero)),
  coachProvider.overrideWithValue(const FakeCoach(latency: Duration.zero)),
  notificationPermissionProvider.overrideWithValue(FakeNotificationPermission()),
  voiceInputProvider.overrideWithValue(voice ?? const UnavailableVoiceInput()),
  isOnlineProvider.overrideWith((ref) => Stream.value(true)),
  hapticsProvider.overrideWithValue(haptics ?? RecordingHaptics()),
  biometricAuthProvider.overrideWithValue(biometric ?? FakeBiometricAuth()),
  authRepositoryProvider.overrideWithValue(testAuthRepository(prefs, isOnline: isOnline)),
  marketDataProvider.overrideWithValue(market ?? const FakeMarketData(latency: Duration.zero)),
  // Fixed rough rates: no network in tests; LiveRateSource has its own tests.
  rateSourceProvider.overrideWithValue(const PlaceholderRateSource()),
  briefSourceProvider.overrideWith(
    (ref) => FakeBrief(
      market: ref.watch(marketDataProvider),
      news: ref.watch(newsCalendarProvider),
      latency: Duration.zero,
    ),
  ),
  briefChatProvider.overrideWithValue(const FakeBriefChat(latency: Duration.zero)),
  remindersProvider.overrideWithValue(reminders ?? FakeReminders()),
];

/// Reminders the test can read back; answers [result] without the OS.
class FakeReminders implements Reminders {
  FakeReminders([this.result = ReminderResult.scheduled]);

  ReminderResult result;
  final scheduled = <({int id, DateTime at, String title, String body})>[];

  @override
  Future<ReminderResult> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (result == ReminderResult.scheduled) scheduled.add((id: id, at: at, title: title, body: body));
    return result;
  }
}
