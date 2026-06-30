/// Schedules the OS-level full-screen alert + sound. Wraps
/// flutter_local_notifications; iOS limits true full-screen takeovers, so the
/// app launches its own [FullScreenAlert] on tap (documented in CLAUDE.md).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:timezone/timezone.dart' as tz;

abstract interface class NotificationService {
  /// [onTap] fires with a reminder id when a notification is tapped or the app
  /// is launched from one (so the UI can open the full-screen alert).
  Future<void> init({void Function(String? reminderId)? onTap});

  Future<bool> requestPermission();

  Future<void> schedule(Reminder reminder);

  Future<void> cancel(String id);

  Future<void> cancelAll();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  // Channel settings (sound, importance) are locked at creation by Android, so a
  // new id is used whenever those change. Bump this to roll out sound changes.
  static const String _channelId = 'memoring_alerts_v3';
  static const String _channelName = 'Reminders';

  /// FLAG_INSISTENT — loops the sound until the user acts (rings like an alarm).
  static final Int32List _insistent = Int32List.fromList([4]);
  static final Int64List _vibration =
      Int64List.fromList([0, 400, 200, 400, 200, 600]);

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
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

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

    final hasImage =
        reminder.imagePath != null && File(reminder.imagePath!).existsSync();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Full-screen reminder alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: reminder.soundEnabled,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _vibration,
      additionalFlags: reminder.soundEnabled ? _insistent : null,
      largeIcon: hasImage ? FilePathAndroidBitmap(reminder.imagePath!) : null,
      styleInformation: hasImage
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(reminder.imagePath!),
              contentTitle: 'Memoring',
              summaryText: reminder.text,
            )
          : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: reminder.soundEnabled,
      interruptionLevel: InterruptionLevel.timeSensitive,
      attachments: hasImage
          ? [DarwinNotificationAttachment(reminder.imagePath!)]
          : null,
    );

    await _plugin.zonedSchedule(
      _intId(reminder.id),
      'Memoring',
      reminder.text,
      tz.TZDateTime.from(reminder.effectiveFireAt, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
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
