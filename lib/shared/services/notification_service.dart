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

  /// Schedules the alert. Returns null on success, or a human-readable warning
  /// if it had to fall back / failed (so the UI can tell the user).
  Future<String?> schedule(Reminder reminder);

  Future<void> cancel(String id);

  Future<void> cancelAll();

  /// Fires a sample alert ~5s out so the user can verify sound/permissions.
  Future<void> scheduleTest();

  /// Shows a notification immediately (bypasses alarm scheduling) — isolates the
  /// display/sound pipeline from alarm-permission/battery issues.
  Future<void> showNow();

  /// Whether the OS currently allows this app to post notifications.
  Future<bool> notificationsAllowed();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  // Channel settings (sound, importance) are locked at creation by Android, so a
  // new id is used whenever those change.
  static const String _channelId = 'memoring_alerts_v4';
  static const String _channelName = 'Reminders';

  // Bundled alarm tone (android/app/src/main/res/raw/alarm.wav).
  static const AndroidNotificationSound _sound =
      RawResourceAndroidNotificationSound('alarm');

  /// FLAG_INSISTENT — loops the sound until the user acts (rings like an alarm).
  static final Int32List _insistent = Int32List.fromList([4]);
  static final Int64List _vibration =
      Int64List.fromList([0, 400, 200, 400, 200, 600]);

  int _intId(String id) => id.hashCode & 0x7fffffff;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

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

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Full-screen reminder alerts',
        importance: Importance.max,
        playSound: true,
        sound: _sound,
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
    final android = _android;
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    // Exact alarms (precise firing) + full-screen intent (Android 14+).
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();

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

  NotificationDetails _details({
    required bool sound,
    ReminderIntensity intensity = ReminderIntensity.low,
    String? imagePath,
  }) {
    final hasImage = imagePath != null && File(imagePath).existsSync();
    // low = one tone; medium/high = loop the sound until acted on;
    // high = ongoing (can't be swiped away — must confirm with a selfie).
    final loops = sound && intensity != ReminderIntensity.low;
    final ongoing = intensity == ReminderIntensity.high;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Full-screen reminder alerts',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: sound,
        sound: sound ? _sound : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: _vibration,
        ongoing: ongoing,
        autoCancel: !ongoing,
        additionalFlags: loops ? _insistent : null,
        largeIcon: hasImage ? FilePathAndroidBitmap(imagePath) : null,
        styleInformation: hasImage
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(imagePath),
                contentTitle: 'Memoring',
                summaryText: '',
              )
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: sound,
        interruptionLevel: InterruptionLevel.timeSensitive,
        attachments:
            hasImage ? [DarwinNotificationAttachment(imagePath)] : null,
      ),
    );
  }

  /// Schedules with exact timing; falls back to inexact if the device blocks
  /// exact alarms. Never throws — returns null on success or a warning string.
  Future<String?> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    String? payload,
  }) async {
    Future<void> run(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: mode,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

    try {
      await run(AndroidScheduleMode.exactAllowWhileIdle);
      return null;
    } catch (_) {
      // Exact alarms blocked → still schedule, but warn it may fire late.
      try {
        await run(AndroidScheduleMode.inexactAllowWhileIdle);
        return 'Exact alarms are off, so timing may be approximate. Turn on '
            '"Alarms & reminders" for Memoring in system settings.';
      } catch (e) {
        return 'Could not set the alarm: $e';
      }
    }
  }

  @override
  Future<String?> schedule(Reminder reminder) async {
    if (!reminder.isActive || reminder.isCompleted) return null;
    return _scheduleAt(
      id: _intId(reminder.id),
      title: 'Memoring',
      body: reminder.text,
      when: tz.TZDateTime.from(reminder.effectiveFireAt, tz.local),
      details: _details(
        sound: reminder.soundEnabled,
        intensity: reminder.intensity,
        imagePath: reminder.imagePath,
      ),
      payload: reminder.id,
    );
  }

  @override
  Future<void> scheduleTest() async {
    await _scheduleAt(
      id: 990001,
      title: 'Memoring test',
      body: 'If you can hear this, your alerts work.',
      when: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      details: _details(sound: true),
    );
  }

  @override
  Future<void> showNow() async {
    await _plugin.show(
      990002,
      'Memoring test',
      'Instant test alert — you should hear this now.',
      _details(sound: true),
    );
  }

  @override
  Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? true;

  @override
  Future<void> cancel(String id) => _plugin.cancel(_intId(id));

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
