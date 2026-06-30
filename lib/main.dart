/// Memoring entry point. Offline-first; no backend, no accounts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/app/app.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone-correct scheduling (DST-safe).
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  } on Exception {
    // Fall back to UTC if the platform can't report a zone.
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
