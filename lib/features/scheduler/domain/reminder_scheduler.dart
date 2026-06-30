/// Classifies reminders (short vs long) and computes the next occurrence of a
/// recurring reminder. Pure functions — no I/O.
library;

import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';

/// A reminder is short-term if it fires within this window.
const Duration kShortTermThreshold = Duration(days: 30);

class ReminderScheduler {
  const ReminderScheduler();

  /// Short vs long queue. Recurring cadence wins; otherwise it's the distance
  /// to the first fire.
  ReminderType classify({
    required DateTime now,
    required DateTime fireAt,
    required Recurrence recurrence,
  }) {
    if (recurrence.isRecurring) {
      return recurrence.isLongTermCadence ? ReminderType.long : ReminderType.short;
    }
    return fireAt.difference(now) >= kShortTermThreshold
        ? ReminderType.long
        : ReminderType.short;
  }

  /// The next fire strictly after [after]. For non-recurring reminders this is
  /// just [current]. Only the next occurrence is computed — never the whole series.
  DateTime nextOccurrence({
    required DateTime current,
    required Recurrence recurrence,
    required DateTime after,
  }) {
    if (!recurrence.isRecurring) return current;
    var next = current;
    var guard = 0;
    while (!next.isAfter(after) && guard < 1000) {
      next = _advance(next, recurrence);
      guard++;
    }
    return next;
  }

  DateTime _advance(DateTime d, Recurrence recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
        return d.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        return d.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        return _addMonths(d, 1);
      case RecurrenceType.yearly:
        return _addMonths(d, 12);
      case RecurrenceType.none:
        return d;
    }
  }

  static DateTime _addMonths(DateTime d, int months) {
    var year = d.year;
    var month = d.month + months;
    year += (month - 1) ~/ 12;
    month = (month - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(year, month, day, d.hour, d.minute);
  }
}
