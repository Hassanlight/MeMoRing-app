/// Renewals — Gulf documents expire and fines hurt. Pick a document, set its
/// expiry once, and 3 reminders are created: 1 month, 1 week, 1 day before.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class RenewalsScreen extends ConsumerStatefulWidget {
  const RenewalsScreen({super.key});

  @override
  ConsumerState<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends ConsumerState<RenewalsScreen> {
  static const _templates = [
    (Icons.badge_outlined, 'Qatar ID'),
    (Icons.flight_takeoff_outlined, 'Visa'),
    (Icons.menu_book_outlined, 'Passport'),
    (Icons.directions_car_outlined, 'Car istimara'),
    (Icons.favorite_outline, 'Health card'),
    (Icons.description_outlined, 'Other document'),
  ];

  String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');

  Future<void> _setup(String doc) async {
    var name = doc;
    if (doc == 'Other document') {
      final controller = TextEditingController();
      final typed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceBlack,
          title: const Text('Document name', style: AppTypography.bodyMedium),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTypography.body,
            cursorColor: AppColors.shinyWhite,
            decoration: const InputDecoration(
                hintText: 'e.g. Driving licence',
                hintStyle: TextStyle(color: AppColors.mutedWhite)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Next',
                    style: TextStyle(color: AppColors.shinyWhite))),
          ],
        ),
      );
      if (typed == null || typed.isEmpty) return;
      name = typed;
    }
    if (!mounted) return;

    final now = DateTime.now();
    final expiry = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 15),
      initialDate: now.add(const Duration(days: 180)),
      helpText: 'When does the $name expire?',
    );
    if (expiry == null || !mounted) return;

    final ctrl = ref.read(remindersControllerProvider);
    final expiryText = formatWhen(DateTime(expiry.year, expiry.month, expiry.day, 9))
        .split(' · ')
        .first;
    final slug = _slug(name);
    final offsets = [
      (const Duration(days: 30), '1 month', '1m'),
      (const Duration(days: 7), '1 week', '1w'),
      (const Duration(days: 1), 'tomorrow', '1d'),
    ];
    var created = 0;
    for (final (offset, label, key) in offsets) {
      final fireAt = DateTime(expiry.year, expiry.month, expiry.day, 9)
          .subtract(offset);
      if (!fireAt.isAfter(now)) continue;
      final lead = key == '1d' ? 'expires TOMORROW' : 'expires in $label';
      await ctrl.create(
        id: 'renewal_${slug}_$key',
        text: '$name $lead ($expiryText) — renew it',
        fireAt: fireAt,
        recurrence: const Recurrence.none(),
        intensity: ReminderIntensity.medium,
      );
      created++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(created > 0
              ? '$name protected — $created reminders set ✓'
              : 'That expiry is too close — set reminders manually')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(remindersProvider).valueOrNull ?? const [];
    final active = all
        .where((r) => r.id.startsWith('renewal_') && !r.isCompleted)
        .toList()
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite)),
        title: const Text('Renewals', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Pick a document — you get warnings 1 month, 1 week and '
                '1 day before it expires.', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.5,
              children: [
                for (final (icon, name) in _templates)
                  GlassCard(
                    onTap: () => _setup(name),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: AppColors.shinyWhite, size: 28),
                        const SizedBox(height: AppSpacing.sm),
                        Text(name,
                            style: AppTypography.caption
                                .copyWith(color: AppColors.shinyWhite),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
              ],
            ),
            if (active.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Upcoming renewal warnings', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              for (final r in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            color: AppColors.mutedWhite, size: 18),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                              '${r.text} · ${formatWhen(r.fireAt)}',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.shinyWhite)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
