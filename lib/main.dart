/// Memoring entry point. Offline-first; no backend, no accounts.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/app/app.dart';
import 'package:memoring/app/router/app_router.dart';
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
  });
}
