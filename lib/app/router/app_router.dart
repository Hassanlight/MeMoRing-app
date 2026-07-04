/// All routes (CLAUDE.md §4). Exposed as a singleton so a fired notification can
/// navigate to the alert from outside the widget tree.
library;

import 'package:go_router/go_router.dart';
import 'package:memoring/app/home_shell.dart';
import 'package:memoring/core/security/pin_gate.dart';
import 'package:memoring/features/alert/presentation/full_screen_alert.dart';
import 'package:memoring/features/dashboard/presentation/dashboard_screen.dart';
import 'package:memoring/features/feedback/presentation/feedback_screen.dart';
import 'package:memoring/features/analytics/presentation/analytics_screen.dart';
import 'package:memoring/features/medicine/presentation/medicine_screen.dart';
import 'package:memoring/features/memories/presentation/memories_screen.dart';
import 'package:memoring/features/onboarding/presentation/onboarding_screen.dart';
import 'package:memoring/features/people/presentation/people_screen.dart';
import 'package:memoring/features/reminders/presentation/home_screen.dart';
import 'package:memoring/features/reminders/presentation/reminder_detail_screen.dart';
import 'package:memoring/features/renewals/presentation/renewals_screen.dart';
import 'package:memoring/features/settings/presentation/settings_screen.dart';
import 'package:memoring/features/vault/presentation/vault_screen.dart';

/// Where the app opens — set by main() before the router is built ('/onboarding'
/// on first run, otherwise '/').
String appInitialLocation = '/';

/// The app's single router instance.
final GoRouter appRouter = _buildRouter();

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: appInitialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/reminders', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/reminder/:id',
        builder: (_, state) =>
            ReminderDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/renewals', builder: (_, __) => const RenewalsScreen()),
      GoRoute(path: '/medicine', builder: (_, __) => const MedicineScreen()),
      GoRoute(path: '/people', builder: (_, __) => const PeopleScreen()),
      GoRoute(
          path: '/vault',
          builder: (_, __) => const PinGate(child: VaultScreen())),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(
          path: '/memories',
          builder: (_, __) => const PinGate(child: MemoriesScreen())),
      GoRoute(
          path: '/dashboard',
          builder: (_, __) => const PinGate(child: DashboardScreen())),
      GoRoute(path: '/feedback', builder: (_, __) => const FeedbackScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/alert/:id',
        builder: (_, state) => FullScreenAlert(id: state.pathParameters['id']!),
      ),
    ],
  );
}
