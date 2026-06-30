/// In-memory repository for v1. Swap for a Drift-backed impl behind
/// [ReminderRepository] without touching presentation. Data is per-session only.
library;

import 'dart:async';

import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';

class InMemoryReminderRepository implements ReminderRepository {
  final Map<String, Reminder> _store = {};
  final StreamController<List<Reminder>> _controller =
      StreamController<List<Reminder>>.broadcast();

  List<Reminder> get _sorted {
    final list = _store.values.toList()
      ..sort((a, b) => a.effectiveFireAt.compareTo(b.effectiveFireAt));
    return List.unmodifiable(list);
  }

  void _emit() => _controller.add(_sorted);

  @override
  Future<List<Reminder>> getAll() async => _sorted;

  @override
  Stream<List<Reminder>> watchAll() async* {
    yield _sorted;
    yield* _controller.stream;
  }

  @override
  Future<void> add(Reminder reminder) async {
    _store[reminder.id] = reminder;
    _emit();
  }

  @override
  Future<void> update(Reminder reminder) async {
    _store[reminder.id] = reminder;
    _emit();
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
    _emit();
  }

  void dispose() => _controller.close();
}
