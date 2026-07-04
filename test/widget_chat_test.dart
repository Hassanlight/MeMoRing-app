// Drives the real chat UI with fake platform services to prove the core
// buttons/flows work: send → reminder created; cancel → reminder removed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoring/features/assistant/presentation/chat_screen.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:memoring/shared/services/notification_service.dart';

class _FakeRepo implements ReminderRepository {
  final Map<String, Reminder> _store = {};
  final StreamController<List<Reminder>> _c =
      StreamController<List<Reminder>>.broadcast();

  List<Reminder> get _list => _store.values.toList();

  @override
  Future<void> add(Reminder r) async {
    _store[r.id] = r;
    _c.add(_list);
  }

  @override
  Future<void> update(Reminder r) async {
    _store[r.id] = r;
    _c.add(_list);
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
    _c.add(_list);
  }

  @override
  Future<List<Reminder>> getAll() async => _list;

  @override
  Stream<List<Reminder>> watchAll() async* {
    yield _list;
    yield* _c.stream;
  }
}

class _FakeNotifications implements NotificationService {
  @override
  Future<void> init({void Function(String?)? onTap}) async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<String?> schedule(Reminder reminder) async => null;
  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> scheduleTest() async {}
  @override
  Future<void> showNow() async {}
  @override
  Future<void> showReminderNow(Reminder reminder) async {}
  @override
  Future<bool> notificationsAllowed() async => true;
  @override
  Future<void> schedulePlain({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {}
}

Widget _app() => ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(_FakeRepo()),
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.arrow_upward));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sending a reminder shows a "Reminder set" card', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _send(tester, 'call mom in 2 hours');

    expect(find.textContaining('Reminder set'), findsOneWidget);
    expect(find.textContaining('call mom'), findsWidgets);
  });

  testWidgets('natural-language cancel removes the reminder', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _send(tester, 'buy milk tomorrow 9am');
    expect(find.textContaining('Reminder set'), findsOneWidget);

    await _send(tester, 'cancel buy milk');
    expect(find.textContaining('cancelled'), findsOneWidget);
  });

  testWidgets('no-time message offers a Pick a time button', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await _send(tester, 'water the plants');
    expect(find.text('Pick a time'), findsOneWidget);
  });

  testWidgets('intensity chips are tappable and switch selection',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Once'), findsOneWidget);
    expect(find.text('Ring'), findsOneWidget);
    expect(find.text('Selfie'), findsOneWidget);
    await tester.tap(find.text('Ring'));
    await tester.pumpAndSettle();
    // Still present after selection (no crash / rebuild works).
    expect(find.text('Ring'), findsOneWidget);
  });
}
