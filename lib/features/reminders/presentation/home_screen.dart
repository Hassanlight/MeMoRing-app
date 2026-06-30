/// Home — the reminders list, segmented Short-term / Long-term.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/widgets/segmented_toggle.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:memoring/features/reminders/presentation/widgets/reminder_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final short = ref.watch(shortTermRemindersProvider);
    final long = ref.watch(longTermRemindersProvider);
    final items = _segment == 0 ? short : long;
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.glassTintStrong,
        elevation: 0,
        onPressed: () => context.go('/'),
        tooltip: 'Add via chat',
        child: const Icon(Icons.add_comment_outlined,
            color: AppColors.shinyWhite, size: 26),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Text('Memoring', style: AppTypography.title),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.mutedWhite),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedToggle(
                segments: const ['Short-term', 'Long-term'],
                selectedIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: remindersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.mutedWhite),
                  ),
                  error: (_, __) => const _ErrorState(),
                  data: (_) => items.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.lg),
                          itemBuilder: (_, i) => ReminderCard(
                            reminder: items[i],
                            onTap: () => context.push('/reminder/${items[i].id}'),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none,
              size: 56, color: AppColors.mutedWhite),
          const SizedBox(height: AppSpacing.lg),
          Text('Nothing scheduled', style: AppTypography.heading),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap + to add your first reminder.',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Couldn't load reminders.", style: AppTypography.caption),
    );
  }
}
