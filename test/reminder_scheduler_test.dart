// Tests for classification + next-occurrence math.
import 'package:flutter_test/flutter_test.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/scheduler/domain/reminder_scheduler.dart';

void main() {
  const scheduler = ReminderScheduler();
  final now = DateTime(2026, 6, 30, 12);

  group('classification', () {
    test('29 days out is short-term', () {
      final t = scheduler.classify(
        now: now,
        fireAt: now.add(const Duration(days: 29)),
        recurrence: const Recurrence.none(),
      );
      expect(t, ReminderType.short);
    });

    test('exactly 30 days out is long-term', () {
      final t = scheduler.classify(
        now: now,
        fireAt: now.add(const Duration(days: 30)),
        recurrence: const Recurrence.none(),
      );
      expect(t, ReminderType.long);
    });

    test('daily cadence is short, monthly is long', () {
      expect(
        scheduler.classify(
          now: now,
          fireAt: now,
          recurrence: const Recurrence(RecurrenceType.daily),
        ),
        ReminderType.short,
      );
      expect(
        scheduler.classify(
          now: now,
          fireAt: now,
          recurrence: const Recurrence(RecurrenceType.monthly),
        ),
        ReminderType.long,
      );
    });
  });

  group('next occurrence', () {
    final base = DateTime(2026, 6, 30, 9); // before `now` (noon)

    test('daily advances one day past now', () {
      final next = scheduler.nextOccurrence(
        current: base,
        recurrence: const Recurrence(RecurrenceType.daily),
        after: now,
      );
      expect(next, DateTime(2026, 7, 1, 9));
    });

    test('weekly advances seven days', () {
      final next = scheduler.nextOccurrence(
        current: base,
        recurrence: const Recurrence(RecurrenceType.weekly),
        after: now,
      );
      expect(next, DateTime(2026, 7, 7, 9));
    });

    test('monthly clamps to month length', () {
      // Jan 31 + 1 month → Feb 28 (2026 not a leap year).
      final next = scheduler.nextOccurrence(
        current: DateTime(2026, 1, 31, 9),
        recurrence: const Recurrence(RecurrenceType.monthly),
        after: DateTime(2026, 2, 1),
      );
      expect(next, DateTime(2026, 2, 28, 9));
    });

    test('non-recurring returns itself', () {
      final next = scheduler.nextOccurrence(
        current: base,
        recurrence: const Recurrence.none(),
        after: now,
      );
      expect(next, base);
    });
  });
}
