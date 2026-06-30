/// Persistence contract. v1 is in-memory; a Drift (SQLite) impl drops in here
/// with no change to callers.
library;

import 'package:memoring/features/reminders/domain/reminder.dart';

abstract interface class ReminderRepository {
  /// All reminders, newest fire-time first.
  Future<List<Reminder>> getAll();

  /// Live stream of all reminders for reactive UI.
  Stream<List<Reminder>> watchAll();

  Future<void> add(Reminder reminder);

  Future<void> update(Reminder reminder);

  Future<void> remove(String id);
}
