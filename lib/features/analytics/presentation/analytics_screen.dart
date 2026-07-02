/// Insights: what the user reminds themselves about most, and usage stats.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/analytics/domain/analytics.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite),
        ),
        title: const Text('Insights', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: remindersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mutedWhite),
          ),
          error: (_, __) =>
              const Center(child: Text("Couldn't load insights")),
          data: (reminders) {
            final a = computeAnalytics(reminders);
            if (a.isEmpty) {
              return const Center(
                child: Text('No data yet — add a few reminders first.',
                    style: AppTypography.caption),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                Row(
                  children: [
                    _Metric(label: 'Total', value: '${a.total}'),
                    const SizedBox(width: AppSpacing.md),
                    _Metric(label: 'Done', value: '${a.completed}'),
                    const SizedBox(width: AppSpacing.md),
                    _Metric(label: 'Active', value: '${a.active}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _Metric(label: 'Completion', value: '${a.completionPercent}%'),
                    const SizedBox(width: AppSpacing.md),
                    _Metric(label: 'Repeating', value: '${a.recurring}'),
                    const SizedBox(width: AppSpacing.md),
                    _Metric(label: 'With photo', value: '${a.withPhoto}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('What you remind yourself about most',
                    style: AppTypography.caption),
                const SizedBox(height: AppSpacing.md),
                GlassCard(
                  child: a.topTopics.isEmpty
                      ? const Text('Not enough words yet.',
                          style: AppTypography.caption)
                      : Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final t in a.topTopics)
                              _TopicChip(word: t.key, count: t.value),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Alert levels used', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.md),
                GlassCard(
                  child: Column(
                    children: [
                      _LevelRow(
                          label: 'Once',
                          count: a.byIntensity[ReminderIntensity.low] ?? 0),
                      const SizedBox(height: AppSpacing.sm),
                      _LevelRow(
                          label: 'Ring',
                          count: a.byIntensity[ReminderIntensity.medium] ?? 0),
                      const SizedBox(height: AppSpacing.sm),
                      _LevelRow(
                          label: 'Selfie',
                          count: a.byIntensity[ReminderIntensity.high] ?? 0),
                    ],
                  ),
                ),
                if (a.prayerLog.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Prayer log', style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.md),
                  for (final p in a.prayerLog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PrayerLogRow(reminder: p),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.glassTint,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTypography.heading),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.word, required this.count});
  final String word;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.glassTintStrong,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text('$word · $count',
          style: AppTypography.caption.copyWith(color: AppColors.shinyWhite)),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTypography.bodyMedium),
        const Spacer(),
        Text('$count', style: AppTypography.bodyMedium),
      ],
    );
  }
}

class _PrayerLogRow extends StatelessWidget {
  const _PrayerLogRow({required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final when = reminder.completedAt ?? reminder.fireAt;
    final hasPhoto =
        reminder.imagePath != null && File(reminder.imagePath!).existsSync();
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.md),
              child: Image.file(File(reminder.imagePath!),
                  width: 52, height: 52, fit: BoxFit.cover, cacheWidth: 104),
            )
          else
            const Icon(Icons.mosque_outlined,
                color: AppColors.mutedWhite, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.text, style: AppTypography.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(formatWhen(when), style: AppTypography.caption),
              ],
            ),
          ),
          const Icon(Icons.check_circle,
              color: AppColors.shortTermAccent, size: 18),
        ],
      ),
    );
  }
}
