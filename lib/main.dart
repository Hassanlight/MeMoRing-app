/// Memoring entry point. Offline-first; no backend, no accounts.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/app/app.dart';
import 'package:memoring/app/router/app_router.dart';
import 'package:memoring/core/telemetry.dart';
import 'package:memoring/features/alert/presentation/full_screen_alert.dart';
import 'package:memoring/features/onboarding/presentation/profile_providers.dart';
import 'package:memoring/features/prayer/presentation/prayer_providers.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reminders are scheduled at an ABSOLUTE instant derived from the device's own
  // DateTime (its real timezone + DST), so they fire at the correct LOCAL time in
  // any region regardless of tz.local. UTC is a safe, neutral base for tz here.
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  final container = ProviderContainer();

  await Telemetry.loadPreference();
  Telemetry.log('app_open');

  // First run → show onboarding; otherwise straight to the chat.
  final profile = await container.read(profileRepositoryProvider).load();
  appInitialLocation = profile == null ? '/onboarding' : '/';

  // Push the alert screen exactly once per reminder, no matter how many launch
  // paths fire (notification tap, full-screen intent, due-checker).
  void openAlert(String id) {
    if (activeAlertId == id) return;
    appRouter.push('/alert/$id');
  }

  final notifications = container.read(notificationServiceProvider);
  await notifications.init(
    onTap: (reminderId) {
      if (reminderId == null || reminderId.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => openAlert(reminderId));
    },
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MemoringApp(),
    ),
  );

  // While the app is open, take over the screen with the full-screen note the
  // moment a reminder is due (the OS notification covers locked/background).
  final alerted = <String>{};
  Timer.periodic(const Duration(seconds: 10), (_) async {
    final repo = container.read(reminderRepositoryProvider);
    final now = DateTime.now();
    for (final r in await repo.getAll()) {
      if (!r.isActive || r.isCompleted || alerted.contains(r.id)) continue;
      final due = r.effectiveFireAt;
      if (!due.isAfter(now) && now.difference(due) < const Duration(minutes: 2)) {
        alerted.add(r.id);
        openAlert(r.id);
        break; // one takeover at a time
      }
    }
  });

  // Ask for notification + exact-alarm permission once the UI is up (a resumed
  // activity is required for the system dialog), then make sure every saved
  // reminder actually has a pending alarm.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // First run: onboarding owns the permission flow (no double prompts).
    if (profile != null) {
      await notifications.requestPermission();
      // Keep prayer reminders current for returning Muslim users.
      await container.read(prayerServiceProvider).sync(profile);
    }
    final repo = container.read(reminderRepositoryProvider);
    final now = DateTime.now();
    for (final r in await repo.getAll()) {
      if (r.isActive && !r.isCompleted && r.effectiveFireAt.isAfter(now)) {
        await notifications.schedule(r);
      }
    }

    // Tomorrow preview — one gentle 9pm note listing tomorrow's reminders,
    // so mornings never surprise the user.
    var preview = DateTime(now.year, now.month, now.day, 21);
    if (!preview.isAfter(now)) preview = preview.add(const Duration(days: 1));
    final targetDay = preview.add(const Duration(days: 1));
    final tomorrows = (await repo.getAll())
        .where((r) =>
            r.isActive &&
            !r.isCompleted &&
            r.effectiveFireAt.year == targetDay.year &&
            r.effectiveFireAt.month == targetDay.month &&
            r.effectiveFireAt.day == targetDay.day)
        .toList()
      ..sort((a, b) => a.effectiveFireAt.compareTo(b.effectiveFireAt));
    if (tomorrows.isNotEmpty) {
      String clock(DateTime d) {
        final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
        final m = d.minute.toString().padLeft(2, '0');
        return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
      }

      final lines = tomorrows
          .take(5)
          .map((r) => '${clock(r.effectiveFireAt)} — ${r.text}')
          .join('\n');
      final extra =
          tomorrows.length > 5 ? '\n…and ${tomorrows.length - 5} more' : '';
      await notifications.schedulePlain(
        id: 990020,
        title: 'Tomorrow: ${tomorrows.length} reminder(s)',
        body: '$lines$extra',
        when: preview,
      );
    }
  });
}
