/// Full-screen takeover shown when a reminder fires. Snooze / Done / Dismiss.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class FullScreenAlert extends ConsumerStatefulWidget {
  const FullScreenAlert({required this.id, super.key});
  final String id;

  @override
  ConsumerState<FullScreenAlert> createState() => _FullScreenAlertState();
}

class _FullScreenAlertState extends ConsumerState<FullScreenAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Reminder? _find() {
    final all = ref.read(remindersProvider).valueOrNull ?? const [];
    for (final r in all) {
      if (r.id == widget.id) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _find();
    if (reminder == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final controller = ref.read(remindersControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.matteBlack,
      body: SafeArea(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(
            CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: _anim,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: reminder.type == ReminderType.short
                          ? AppColors.shortTermAccent
                          : AppColors.longTermAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    reminder.text,
                    style: AppTypography.alert,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(formatWhen(reminder.fireAt), style: AppTypography.caption),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          label: 'Snooze',
                          onPressed: () async {
                            await controller.snooze(
                                reminder, const Duration(minutes: 15));
                            if (context.mounted) context.pop();
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: GlassButton(
                          label: 'Done',
                          filled: true,
                          onPressed: () async {
                            await controller.complete(reminder);
                            if (context.mounted) context.pop();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Dismiss',
                        style: TextStyle(color: AppColors.mutedWhite)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
