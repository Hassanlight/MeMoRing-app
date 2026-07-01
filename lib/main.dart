/// Memoring entry point. Offline-first; no backend, no accounts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/app/app.dart';
import 'package:memoring/app/router/app_router.dart';
import 'package:memoring/features/onboarding/presentation/profile_providers.dart';
import 'package:memoring/features/prayer/presentation/prayer_providers.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone-correct scheduling (DST-safe). Device-timezone auto-detection was
  // removed to keep the Android build toolchain-clean; default to the launch
  // market (Qatar) and fall back to UTC.
  // TODO(scheduler): restore dynamic device-timezone detection before
  // multi-region release.
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Qatar'));
  } on Object {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  final container = ProviderContainer();

  // First run → show onboarding; otherwise straight to the chat.
  final profile = await container.read(profileRepositoryProvider).load();
  appInitialLocation = profile == null ? '/onboarding' : '/';

  final notifications = container.read(notificationServiceProvider);
  await notifications.init(
    onTap: (reminderId) {
      if (reminderId == null || reminderId.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.push('/alert/$reminderId');
      });
    },
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MemoringApp(),
    ),
  );

  // Ask for notification + exact-alarm permission once the UI is up (a resumed
  // activity is required for the system dialog), then make sure every saved
  // reminder actually has a pending alarm.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await notifications.requestPermission();
    // Keep prayer reminders current for returning Muslim users.
    if (profile != null) {
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
