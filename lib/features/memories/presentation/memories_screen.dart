/// Memories — every completed reminder that has a photo (confirmation selfies
/// and attachments), newest first, so users can look back on what they did.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite),
        ),
        title: const Text('Memories', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: remindersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mutedWhite),
          ),
          error: (_, __) =>
              const Center(child: Text("Couldn't load memories")),
          data: (reminders) {
            final memories = reminders
                .where((r) =>
                    r.isCompleted &&
                    r.imagePath != null &&
                    File(r.imagePath!).existsSync())
                .toList()
              ..sort((a, b) => (b.completedAt ?? b.fireAt)
                  .compareTo(a.completedAt ?? a.fireAt));

            if (memories.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          size: 56, color: AppColors.mutedWhite),
                      const SizedBox(height: AppSpacing.lg),
                      Text('No memories yet', style: AppTypography.heading),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Photos from completed reminders — including your '
                        'confirmation selfies — appear here.',
                        style: AppTypography.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.screen),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.8,
              ),
              itemCount: memories.length,
              itemBuilder: (_, i) => _MemoryTile(reminder: memories[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final when = reminder.completedAt ?? reminder.fireAt;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(reminder.imagePath!),
            fit: BoxFit.cover,
            cacheWidth: 480,
          ),
          // Caption band over the photo bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: AppColors.matteBlack.withOpacity(0.65),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reminder.text,
                    style: AppTypography.bodyMedium.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(formatWhen(when),
                      style: AppTypography.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
