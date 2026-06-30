/// All routes (CLAUDE.md §4). Exposed as a singleton so a fired notification can
/// navigate to the alert from outside the widget tree.
library;

import 'package:go_router/go_router.dart';
import 'package:memoring/features/alert/presentation/full_screen_alert.dart';
import 'package:memoring/features/assistant/presentation/chat_screen.dart';
import 'package:memoring/features/reminders/presentation/home_screen.dart';
import 'package:memoring/features/reminders/presentation/reminder_detail_screen.dart';
import 'package:memoring/features/settings/presentation/settings_screen.dart';

/// The app's single router instance.
final GoRouter appRouter = _buildRouter();

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/reminders', builder: (_, __) => const HomeScreen()),
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
