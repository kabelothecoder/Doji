import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/platform/platform_info.dart';

// --- Notifications -------------------------------------------------------------

enum NotificationPermissionResult { granted, denied }

/// Step 5b priming: explain the value first, then the OS prompt.
abstract interface class NotificationPermission {
  Future<NotificationPermissionResult> request();
}

class PermissionHandlerNotifications implements NotificationPermission {
  const PermissionHandlerNotifications();

  @override
  Future<NotificationPermissionResult> request() async {
    // Windows toasts need no runtime prompt.
    if (PlatformInfo.isDesktop) return NotificationPermissionResult.granted;
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isProvisional
          ? NotificationPermissionResult.granted
          : NotificationPermissionResult.denied;
    } on Object {
      return NotificationPermissionResult.denied;
    }
  }
}

final notificationPermissionProvider = Provider<NotificationPermission>(
  (ref) => const PermissionHandlerNotifications(),
);

// --- Time zone -----------------------------------------------------------------

class DetectedTimeZone {
  const DetectedTimeZone({required this.id, required this.offsetMinutes, this.detected = true});

  /// IANA id when known (Africa/Johannesburg), otherwise the OS abbreviation.
  final String id;
  final int offsetMinutes;
  final bool detected;

  Map<String, Object?> toJson() => {'id': id, 'offsetMinutes': offsetMinutes, 'detected': detected};
}

abstract interface class TimeZoneService {
  Future<DetectedTimeZone> detect();
}

class PluginTimeZoneService implements TimeZoneService {
  const PluginTimeZoneService();

  @override
  Future<DetectedTimeZone> detect() async {
    final now = DateTime.now();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return DetectedTimeZone(id: info.identifier, offsetMinutes: now.timeZoneOffset.inMinutes);
    } on Object {
      return DetectedTimeZone(id: now.timeZoneName, offsetMinutes: now.timeZoneOffset.inMinutes);
    }
  }
}

final timeZoneServiceProvider = Provider<TimeZoneService>((ref) => const PluginTimeZoneService());
