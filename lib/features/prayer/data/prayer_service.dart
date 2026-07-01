/// Computes the five daily prayers offline (adhan) and schedules them as
/// reminders. Muslim users only; opt-in via the profile.
library;

import 'package:adhan/adhan.dart';
import 'package:memoring/features/onboarding/domain/user_profile.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';
import 'package:memoring/shared/services/notification_service.dart';

class PrayerService {
  PrayerService(this._repo, this._notifications);

  final ReminderRepository _repo;
  final NotificationService _notifications;

  // Default location: Doha, Qatar. (City selection can be added later.)
  static final Coordinates _coordinates = Coordinates(25.2854, 51.5310);

  static String _two(int n) => n.toString().padLeft(2, '0');

  static const _names = {
    'fajr': 'Fajr',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
  };

  /// Reconciles prayer reminders with the profile. Removes them if disabled;
  /// otherwise (re)schedules today's + tomorrow's upcoming prayers.
  Future<void> sync(UserProfile profile) async {
    final existing =
        (await _repo.getAll()).where((r) => r.id.startsWith('prayer_')).toList();

    // Disabled → clear everything and stop.
    if (!profile.isMuslim || !profile.prayerReminders) {
      for (final r in existing) {
        await _notifications.cancel(r.id);
        await _repo.remove(r.id);
      }
      return;
    }

    // Prune only past prayers the user MISSED; keep completed ones as history
    // (their selfie photos power the prayer log in Insights).
    final now = DateTime.now();
    final completedIds = <String>{};
    for (final r in existing) {
      if (r.isCompleted) {
        completedIds.add(r.id);
      } else if (r.fireAt.isBefore(now)) {
        await _repo.remove(r.id);
      }
    }

    final params = CalculationMethod.qatar.getParameters()
      ..madhab = Madhab.shafi;
    final intensity =
        profile.prayerSelfie ? ReminderIntensity.high : ReminderIntensity.medium;

    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final date = DateTime.now().add(Duration(days: dayOffset));
      final components = DateComponents.from(date);
      final times = PrayerTimes(_coordinates, components, params);
      final ymd = '${date.year}${_two(date.month)}${_two(date.day)}';

      final byName = <String, DateTime>{
        'fajr': times.fajr.toLocal(),
        'dhuhr': times.dhuhr.toLocal(),
        'asr': times.asr.toLocal(),
        'maghrib': times.maghrib.toLocal(),
        'isha': times.isha.toLocal(),
      };

      for (final entry in byName.entries) {
        final fireAt = entry.value;
        if (!fireAt.isAfter(now)) continue;
        final id = 'prayer_${entry.key}_$ymd';
        if (completedIds.contains(id)) continue; // already done — keep history
        final reminder = Reminder(
          id: id,
          text: '${_names[entry.key]} prayer',
          createdAt: now,
          fireAt: fireAt,
          type: ReminderType.short,
          recurrence: const Recurrence.none(),
          intensity: intensity,
        );
        await _repo.update(reminder); // upsert by id
        await _notifications.schedule(reminder);
      }
    }
  }
}
