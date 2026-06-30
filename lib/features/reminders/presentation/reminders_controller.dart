/// Providers + controller that own reminder state and wire every button to the
/// repository, scheduler, and notification service.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/core/result.dart';
import 'package:memoring/features/reminders/data/in_memory_reminder_repository.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';
import 'package:memoring/features/scheduler/domain/reminder_scheduler.dart';
import 'package:memoring/features/scheduler/presentation/scheduler_providers.dart';
import 'package:memoring/shared/services/notification_service.dart';
import 'package:uuid/uuid.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final repo = InMemoryReminderRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(FlutterLocalNotificationsPlugin()),
);

/// Live list of all reminders.
final remindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchAll(),
);

/// Reminders filtered to the short-term queue.
final shortTermRemindersProvider = Provider<List<Reminder>>((ref) {
  return ref.watch(remindersProvider).maybeWhen(
        data: (r) => r.where((x) => x.type == ReminderType.short && !x.isCompleted).toList(),
        orElse: () => const [],
      );
});

/// Reminders filtered to the long-term queue.
final longTermRemindersProvider = Provider<List<Reminder>>((ref) {
  return ref.watch(remindersProvider).maybeWhen(
        data: (r) => r.where((x) => x.type == ReminderType.long && !x.isCompleted).toList(),
        orElse: () => const [],
      );
});

final remindersControllerProvider =
    Provider<RemindersController>(RemindersController.new);

/// All reminder mutations live here. Widgets call these; they never touch the
/// repository or scheduler directly.
class RemindersController {
  RemindersController(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  ReminderRepository get _repo => _ref.read(reminderRepositoryProvider);
  ReminderScheduler get _scheduler => _ref.read(schedulerProvider);
  NotificationService get _notifications => _ref.read(notificationServiceProvider);

  /// Create a reminder from already-parsed pieces. Returns the new reminder or
  /// a user-safe error.
  Future<Result<Reminder>> create({
    required String text,
    required DateTime fireAt,
    required Recurrence recurrence,
    bool soundEnabled = true,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return const Err('Add a few words about what to remember.');
    if (!fireAt.isAfter(DateTime.now())) {
      return const Err('That time has already passed.');
    }
    final reminder = Reminder(
      id: _uuid.v4(),
      text: clean,
      createdAt: DateTime.now(),
      fireAt: fireAt,
      type: _scheduler.classify(
        now: DateTime.now(),
        fireAt: fireAt,
        recurrence: recurrence,
      ),
      recurrence: recurrence,
      soundEnabled: soundEnabled,
    );
    await _repo.add(reminder);
    await _notifications.schedule(reminder);
    return Ok(reminder);
  }

  Future<void> save(Reminder reminder) async {
    await _repo.update(reminder);
    await _notifications.cancel(reminder.id);
    await _notifications.schedule(reminder);
  }

  Future<void> delete(String id) async {
    await _repo.remove(id);
    await _notifications.cancel(id);
  }

  Future<void> setSound(Reminder reminder, {required bool enabled}) =>
      save(reminder.copyWith(soundEnabled: enabled));

  /// Snooze N minutes from now without losing the recurrence rule.
  Future<void> snooze(Reminder reminder, Duration by) =>
      save(reminder.copyWith(snoozedUntil: () => DateTime.now().add(by)));

  /// Mark done. Recurring reminders re-arm to their next occurrence instead of
  /// completing — recurrence is never lost.
  Future<void> complete(Reminder reminder) async {
    if (reminder.recurrence.isRecurring) {
      final next = _scheduler.nextOccurrence(
        current: reminder.fireAt,
        recurrence: reminder.recurrence,
        after: DateTime.now(),
      );
      await save(reminder.copyWith(
        fireAt: next,
        snoozedUntil: () => null,
      ));
    } else {
      await save(reminder.copyWith(
        completedAt: () => DateTime.now(),
        isActive: false,
      ));
      await _notifications.cancel(reminder.id);
    }
  }
}
