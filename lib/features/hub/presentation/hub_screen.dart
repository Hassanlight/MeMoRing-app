/// Life hub — one big friendly card per life problem. Max 2 taps to anything.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/widgets/glass_card.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.badge_outlined, 'Renewals', 'Qatar ID, visa, passport — never pay a late fine', '/renewals'),
      (Icons.medication_outlined, 'Medicine', 'Daily doses with photo proof', '/medicine'),
      (Icons.cake_outlined, 'People', 'Birthdays — reminded the day before', '/people'),
      (Icons.search, 'Vault', '"Where did I put it?" — photo + note', '/vault'),
      (Icons.photo_library_outlined, 'Memories', 'Photos from things you completed', '/memories'),
      (Icons.insights_outlined, 'Insights', 'What you remind yourself about most', '/analytics'),
      (Icons.shield_outlined, 'Dashboard', 'Your data, app lock, storage — all private', '/dashboard'),
      (Icons.settings_outlined, 'Settings', 'Alerts, prayer times, permissions', '/settings'),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text('Life', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text('Tools for the things people forget',
                style: AppTypography.caption),
            const SizedBox(height: AppSpacing.lg),
            for (final (icon, title, subtitle, route) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GlassCard(
                  onTap: () => context.push(route),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.glassTintStrong,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusButton),
                        ),
                        child:
                            Icon(icon, color: AppColors.shinyWhite, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppTypography.bodyMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(subtitle, style: AppTypography.caption),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.mutedWhite),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
