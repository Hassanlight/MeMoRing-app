/// Reminder detail / edit — change text, time, recurrence, sound; or delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class ReminderDetailScreen extends ConsumerStatefulWidget {
  const ReminderDetailScreen({required this.id, super.key});
  final String id;

  @override
  ConsumerState<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends ConsumerState<ReminderDetailScreen> {
  Reminder? _draft;
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
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
    final source = _find();
    if (source == null) {
      return const Scaffold(
        body: Center(child: Text('Reminder not found')),
      );
    }
    final draft = _draft ??= source;
    if (_textController.text.isEmpty && draft.text.isNotEmpty) {
      _textController.text = draft.text;
    }

    Future<void> pickTime() async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: DateTime(now.year + 5),
        initialDate: draft.fireAt.isAfter(now) ? draft.fireAt : now,
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(draft.fireAt),
      );
      if (time == null || !mounted) return;
      setState(() => _draft = draft.copyWith(
            fireAt: DateTime(date.year, date.month, date.day, time.hour, time.minute),
          ));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite),
        ),
        title: const Text('Edit reminder', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            GlassCard(
              child: TextField(
                controller: _textController,
                style: AppTypography.body,
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Reminder text',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
                onChanged: (v) => _draft = draft.copyWith(text: v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              onTap: pickTime,
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.mutedWhite, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text(formatWhen(draft.fireAt), style: AppTypography.bodyMedium),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.mutedWhite),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Repeat', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            _RecurrencePicker(
              value: draft.recurrence.type,
              onChanged: (t) => setState(
                () => _draft = draft.copyWith(recurrence: Recurrence(t)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.volume_up_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text('Sound', style: AppTypography.bodyMedium),
                  const Spacer(),
                  Switch(
                    value: draft.soundEnabled,
                    activeColor: AppColors.shinyWhite,
                    onChanged: (v) =>
                        setState(() => _draft = draft.copyWith(soundEnabled: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
              label: 'Save changes',
              filled: true,
              onPressed: () async {
                await ref.read(remindersControllerProvider).save(
                      draft.copyWith(text: _textController.text.trim()),
                    );
                if (context.mounted) context.pop();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            GlassButton(
              label: 'Delete',
              danger: true,
              onPressed: () => _confirmDelete(context, ref, draft.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceBlack,
        title: const Text('Delete reminder?', style: AppTypography.bodyMedium),
        content: Text("This can't be undone.", style: AppTypography.caption),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mutedWhite)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(remindersControllerProvider).delete(id);
      if (context.mounted) context.pop();
    }
  }
}

class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker({required this.value, required this.onChanged});
  final RecurrenceType value;
  final ValueChanged<RecurrenceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final t in RecurrenceType.values)
          GestureDetector(
            onTap: () => onChanged(t),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: t == value ? AppColors.glassTintStrong : AppColors.glassTint,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Text(
                t == RecurrenceType.none ? 'none' : t.name,
                style: AppTypography.caption.copyWith(
                  color: t == value ? AppColors.shinyWhite : AppColors.mutedWhite,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
