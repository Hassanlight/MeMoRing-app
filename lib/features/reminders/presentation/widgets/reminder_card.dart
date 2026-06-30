/// A single reminder row: tag dot + relative time + text + meta.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({required this.reminder, this.onTap, super.key});

  final Reminder reminder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fireAt = reminder.effectiveFireAt;
    final overdue = fireAt.isBefore(DateTime.now());
    final tagColor = overdue
        ? AppColors.dangerRed
        : reminder.type == ReminderType.short
            ? AppColors.shortTermAccent
            : AppColors.longTermAccent;

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatRelative(fireAt),
                style: AppTypography.caption.copyWith(
                  color: tagColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (reminder.recurrence.isRecurring)
                const Icon(Icons.repeat, size: 15, color: AppColors.mutedWhite),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reminder.text,
            style: AppTypography.bodyMedium.copyWith(fontSize: 17),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(formatWhen(fireAt), style: AppTypography.caption),
        ],
      ),
    );
  }
}
