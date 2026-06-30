/// Memoring entry point. Offline-first; no backend, no accounts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/app/app.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone-correct scheduling (DST-safe). Device-timezone auto-detection was
  // removed to keep the Android build toolchain-clean; default to the launch
  // market (Qatar) and fall back to UTC.
  // TODO(scheduler): restore dynamic device-timezone detection with a
  // Gradle-compatible plugin before multi-region release.
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Qatar'));
  } on Object {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  final container = ProviderContainer();
  await container.read(notificationServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MemoringApp(),
    ),
  );
}
