// Smoke tests for the Life-hub features: each screen renders, its primary
// action works, and the resulting reminders/items actually exist.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoring/features/hub/presentation/hub_screen.dart';
import 'package:memoring/features/medicine/presentation/medicine_screen.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/domain/reminder_repository.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:memoring/features/renewals/presentation/renewals_screen.dart';
import 'package:memoring/features/vault/presentation/vault_screen.dart';
import 'package:memoring/shared/services/notification_service.dart';

class _FakeRepo implements ReminderRepository {
  final Map<String, Reminder> store = {};
  final StreamController<List<Reminder>> _c =
      StreamController<List<Reminder>>.broadcast();

  List<Reminder> get _list => store.values.toList();

  @override
  Future<void> add(Reminder r) async {
    store[r.id] = r;
    _c.add(_list);
  }

  @override
  Future<void> update(Reminder r) async {
    store[r.id] = r;
    _c.add(_list);
  }

  @override
  Future<void> remove(String id) async {
    store.remove(id);
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

Widget _app(Widget child, _FakeRepo repo) => ProviderScope(
      overrides: [
        reminderRepositoryProvider.overrideWithValue(repo),
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('hub shows every life card', (tester) async {
    // Tall viewport so the lazy list builds every card.
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const HubScreen(), _FakeRepo()));
    await tester.pumpAndSettle();
    for (final title in [
      'Renewals', 'Medicine', 'People', 'Vault', 'Memories', 'Insights',
      'Dashboard', 'Settings',
    ]) {
      expect(find.text(title), findsOneWidget, reason: 'missing $title card');
    }
  });

  testWidgets('renewals shows all document templates', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const RenewalsScreen(), _FakeRepo()));
    await tester.pumpAndSettle();
    for (final doc in [
      'National ID', 'Visa / Residence', 'Passport', 'Car registration',
      'Driving licence', 'Health card / Insurance',
    ]) {
      expect(find.text(doc), findsOneWidget, reason: 'missing $doc template');
    }
  });

  testWidgets('medicine creates daily dose reminders', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_app(const MedicineScreen(), repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Panadol');
    await tester.tap(find.text('Set medicine reminders'));
    await tester.pumpAndSettle();

    final meds = repo.store.keys.where((k) => k.startsWith('med_')).toList();
    expect(meds, isNotEmpty, reason: 'no med_ reminders created');
    final r = repo.store[meds.first]!;
    expect(r.recurrence.type, RecurrenceType.daily);
    expect(r.text, contains('Panadol'));
  });

  testWidgets('vault saves and searches a note', (tester) async {
    await tester.pumpWidget(_app(const VaultScreen(), _FakeRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField).first, 'Passport in black drawer');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Passport in black drawer'), findsOneWidget);

    // Search misses → row hidden; search hits → row shown.
    await tester.enterText(find.byType(TextField).last, 'keys');
    await tester.pumpAndSettle();
    expect(find.text('Passport in black drawer'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'passport');
    await tester.pumpAndSettle();
    expect(find.text('Passport in black drawer'), findsOneWidget);
  });
}
