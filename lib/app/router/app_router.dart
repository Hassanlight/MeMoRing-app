/// All routes (CLAUDE.md §4). The alert route is launchable from a notification.
library;

import 'package:go_router/go_router.dart';
import 'package:memoring/features/alert/presentation/full_screen_alert.dart';
import 'package:memoring/features/compose/presentation/compose_screen.dart';
import 'package:memoring/features/reminders/presentation/home_screen.dart';
import 'package:memoring/features/reminders/presentation/reminder_detail_screen.dart';
import 'package:memoring/features/settings/presentation/settings_screen.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/compose', builder: (_, __) => const ComposeScreen()),
      GoRoute(
        path: '/reminder/:id',
        builder: (_, state) =>
            ReminderDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/alert/:id',
        builder: (_, state) => FullScreenAlert(id: state.pathParameters['id']!),
      ),
    ],
  );
}
