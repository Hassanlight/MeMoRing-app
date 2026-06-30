/// Schedules the OS-level full-screen alert + sound. Wraps
/// flutter_local_notifications; iOS limits true full-screen takeovers, so the
/// app launches its own [FullScreenAlert] on tap (documented in CLAUDE.md).
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:timezone/timezone.dart' as tz;

abstract interface class NotificationService {
  /// [onTap] fires with a reminder id when a notification is tapped or the app
  /// is launched from one (so the UI can open the full-screen alert).
  Future<void> init({void Function(String? reminderId)? onTap});

  /// Ask for notification + exact-alarm permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Schedule (or reschedule) the alert for [reminder] at its effective time.
  Future<void> schedule(Reminder reminder);

  Future<void> cancel(String id);

  Future<void> cancelAll();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'memoring_alerts';
  static const String _channelName = 'Reminders';

  /// Stable, collision-free int id derived from the reminder's uuid.
  int _intId(String id) => id.hashCode & 0x7fffffff;

  @override
  Future<void> init({void Function(String? reminderId)? onTap}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) => onTap?.call(resp.payload),
    );

    // High-importance channel so alerts are full-screen + audible.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Full-screen reminder alerts',
            importance: Importance.max,
            playSound: true,
          ),
        );

    // App cold-launched by tapping a notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if ((launch?.didNotificationLaunchApp ?? false) && onTap != null) {
      onTap(launch!.notificationResponse?.payload);
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    // Exact alarms are required for precise firing on Android 12+.
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        ) ??
        true;

    return androidGranted || iosGranted;
  }

  @override
  Future<void> schedule(Reminder reminder) async {
    if (!reminder.isActive || reminder.isCompleted) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Full-screen reminder alerts',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: reminder.soundEnabled,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: reminder.soundEnabled,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _plugin.zonedSchedule(
      _intId(reminder.id),
      'Memoring',
      reminder.text,
      tz.TZDateTime.from(reminder.effectiveFireAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: reminder.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(String id) => _plugin.cancel(_intId(id));

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
