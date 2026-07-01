/// All routes (CLAUDE.md §4). Exposed as a singleton so a fired notification can
/// navigate to the alert from outside the widget tree.
library;

import 'package:go_router/go_router.dart';
import 'package:memoring/features/alert/presentation/full_screen_alert.dart';
import 'package:memoring/features/analytics/presentation/analytics_screen.dart';
import 'package:memoring/features/assistant/presentation/chat_screen.dart';
import 'package:memoring/features/onboarding/presentation/onboarding_screen.dart';
import 'package:memoring/features/reminders/presentation/home_screen.dart';
import 'package:memoring/features/reminders/presentation/reminder_detail_screen.dart';
import 'package:memoring/features/settings/presentation/settings_screen.dart';

/// Where the app opens — set by main() before the router is built ('/onboarding'
/// on first run, otherwise '/').
String appInitialLocation = '/';

/// The app's single router instance.
final GoRouter appRouter = _buildRouter();

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: appInitialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/reminders', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/reminder/:id',
        builder: (_, state) =>
            ReminderDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/alert/:id',
        builder: (_, state) => FullScreenAlert(id: state.pathParameters['id']!),
      ),
    ],
  );
}
