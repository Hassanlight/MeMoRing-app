/// Computes the five daily prayers offline (adhan) and schedules them as
/// reminders. Muslim users only; opt-in via the profile.
library;

import 'package:adhan/adhan.dart';
import 'package:memoring/features/onboarding/domain/user_profile.dart';
import 'package:memoring/features/prayer/data/prayer_cities.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';
import 'package:memoring/shared/services/notification_service.dart';

class PrayerService {
  PrayerService(this._repo, this._notifications);

  final ReminderRepository _repo;
  final NotificationService _notifications;

  static CalculationParameters _methodFor(String method) {
    switch (method) {
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'turkey':
        return CalculationMethod.turkey.getParameters();
      case 'tehran':
        return CalculationMethod.tehran.getParameters();
      case 'singapore':
        return CalculationMethod.singapore.getParameters();
      case 'north_america':
        return CalculationMethod.north_america.getParameters();
      case 'moon_sighting_committee':
        return CalculationMethod.moon_sighting_committee.getParameters();
      default:
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }

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

    final city = cityByName(profile.prayerCity);
    final coordinates = Coordinates(city.lat, city.lng);
    final params = _methodFor(city.method)..madhab = Madhab.shafi;
    final intensity = profile.prayerIntensity;

    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final date = DateTime.now().add(Duration(days: dayOffset));
      final components = DateComponents.from(date);
      final times = PrayerTimes(coordinates, components, params);
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
