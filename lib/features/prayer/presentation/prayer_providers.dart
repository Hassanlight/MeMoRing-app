/// Provider for the prayer scheduling service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/features/prayer/data/prayer_service.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

final prayerServiceProvider = Provider<PrayerService>(
  (ref) => PrayerService(
    ref.read(reminderRepositoryProvider),
    ref.read(notificationServiceProvider),
  ),
);
