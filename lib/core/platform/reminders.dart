import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'platform_info.dart';

enum ReminderResult {
  scheduled,

  /// Notifications are off for doji (the OS prompt was refused).
  denied,

  /// The time has passed, or this device can't schedule one.
  unavailable,
}

/// One local notification at a set time ("remind me" on 1b). The UI only
/// sees this; [LocalNotificationReminders] is the device implementation.
abstract interface class Reminders {
  /// Schedules [title] / [body] for [at] (any zone). Scheduling the same [id]
  /// again replaces it.
  Future<ReminderResult> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });
}

/// `flutter_local_notifications`: an inexact alarm on Android (no exact-alarm
/// permission needed; Android may deliver it a few minutes late), a
/// UNNotification on iOS and a toast on Windows. Asks for permission on first
/// use (Android 13+, iOS); Windows needs none.
class LocalNotificationReminders implements Reminders {
  LocalNotificationReminders();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'doji_reminders',
    'reminders',
    channelDescription: 'check-again reminders you set on a brief',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<bool> _init() async {
    if (_ready) return true;
    if (kIsWeb) return false;
    tzdata.initializeTimeZones();
    final ok = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked when a reminder is set, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'doji',
          appUserModelId: 'com.doji.app',
          guid: '6b0b9f3e-3c55-4a8e-9a0e-2f4d1c7d5e21',
        ),
      ),
    );
    _ready = ok ?? false;
    return _ready;
  }

  Future<bool> _permitted() async {
    if (PlatformInfo.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (PlatformInfo.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<ReminderResult> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!at.isAfter(DateTime.now())) return ReminderResult.unavailable;
    try {
      if (!await _init()) return ReminderResult.unavailable;
      if (!await _permitted()) return ReminderResult.denied;
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return ReminderResult.scheduled;
    } on Object {
      return ReminderResult.unavailable;
    }
  }
}

final remindersProvider = Provider<Reminders>((ref) => LocalNotificationReminders());
