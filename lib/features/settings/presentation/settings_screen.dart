/// Settings — permissions, sound default, and the privacy promise.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite),
        ),
        title: const Text('Settings', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            GlassCard(
              onTap: () async {
                final granted = await ref
                    .read(notificationServiceProvider)
                    .requestPermission();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(granted
                          ? 'Notifications enabled'
                          : 'Notifications are off — enable them in system settings'),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text('Notification permission', style: AppTypography.bodyMedium),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.mutedWhite),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              onTap: () async {
                await ref.read(notificationServiceProvider).scheduleTest();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test alert in 5 seconds — lock or background the app'),
                    ),
                  );
                }
              },
              child: const Row(
                children: [
                  Icon(Icons.notifications_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  SizedBox(width: AppSpacing.md),
                  Text('Send a test alert', style: AppTypography.bodyMedium),
                  Spacer(),
                  Icon(Icons.play_arrow, color: AppColors.mutedWhite),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GlassCard(
              child: Row(
                children: [
                  Icon(Icons.palette_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  SizedBox(width: AppSpacing.md),
                  Text('Appearance', style: AppTypography.bodyMedium),
                  Spacer(),
                  Text('Matte black', style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: AppColors.mutedWhite, size: 20),
                      SizedBox(width: AppSpacing.md),
                      Text('Privacy', style: AppTypography.bodyMedium),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your reminders never leave this device. No account, no cloud, '
                    'no tracking.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
