// Tests for usage-analytics computation.
import 'package:flutter_test/flutter_test.dart';
import 'package:memoring/features/analytics/domain/analytics.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';

void main() {
  final base = DateTime(2026, 7, 1, 12);

  Reminder make(
    String id,
    String text, {
    bool done = false,
    Recurrence recurrence = const Recurrence.none(),
    ReminderIntensity intensity = ReminderIntensity.low,
    String? image,
  }) =>
      Reminder(
        id: id,
        text: text,
        createdAt: base,
        fireAt: base,
        type: ReminderType.short,
        recurrence: recurrence,
        intensity: intensity,
        imagePath: image,
        completedAt: done ? base : null,
      );

  test('counts totals, completion, recurring, photos, intensity', () {
    final a = computeAnalytics([
      make('1', 'water the plants'),
      make('2', 'water the plants again', done: true),
      make('3', 'gym workout',
          recurrence: const Recurrence(RecurrenceType.daily),
          intensity: ReminderIntensity.high,
          image: '/tmp/x.jpg'),
    ]);

    expect(a.total, 3);
    expect(a.completed, 1);
    expect(a.active, 2);
    expect(a.recurring, 1);
    expect(a.withPhoto, 1);
    expect(a.completionPercent, 33);
    expect(a.byIntensity[ReminderIntensity.high], 1);
  });

  test('surfaces the most frequent topic words', () {
    final a = computeAnalytics([
      make('1', 'water plants'),
      make('2', 'water plants'),
      make('3', 'water garden'),
    ]);
    // "water" appears 3x → should be the top topic.
    expect(a.topTopics.first.key, 'water');
    expect(a.topTopics.first.value, 3);
  });

  test('empty input', () {
    expect(computeAnalytics(const []).isEmpty, isTrue);
  });
}
