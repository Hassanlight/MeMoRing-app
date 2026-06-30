/// JSON-file repository — reminders (and their photo paths) survive app restarts.
/// Implements [ReminderRepository]; swaps in for the in-memory one with no UI change.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';
import 'package:path_provider/path_provider.dart';

class FileReminderRepository implements ReminderRepository {
  FileReminderRepository() {
    unawaited(_load());
  }

  final Map<String, Reminder> _store = {};
  final StreamController<List<Reminder>> _controller =
      StreamController<List<Reminder>>.broadcast();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/reminders.json');
  }

  Future<void> _load() async {
    try {
      final f = await _file();
      if (f.existsSync()) {
        final raw = jsonDecode(await f.readAsString()) as List<dynamic>;
        for (final e in raw) {
          final r = Reminder.fromJson(e as Map<String, dynamic>);
          _store[r.id] = r;
        }
      }
    } on Object {
      // Corrupt/missing file → start empty rather than crash.
    }
    _emit();
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      await f.writeAsString(
        jsonEncode(_store.values.map((e) => e.toJson()).toList()),
      );
    } on Object {
      // Best-effort; never crash the UI on a write error.
    }
  }

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
    await _persist();
  }

  @override
  Future<void> update(Reminder reminder) async {
    _store[reminder.id] = reminder;
    _emit();
    await _persist();
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
    _emit();
    await _persist();
  }

  void dispose() => _controller.close();
}
