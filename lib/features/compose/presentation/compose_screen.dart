/// Compose — type a reminder; the parser previews the time live.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/result.dart';
import 'package:memoring/core/time_format.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:memoring/features/scheduler/domain/parsed_reminder.dart';
import 'package:memoring/features/scheduler/presentation/scheduler_providers.dart';

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Reset the draft when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(composeDraftProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String text, DateTime fireAt, Recurrence recurrence) async {
    setState(() => _saving = true);
    final result = await ref.read(remindersControllerProvider).create(
          text: text,
          fireAt: fireAt,
          recurrence: recurrence,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        context.pop();
      case Err(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pickManualTime(String cleanText) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final fireAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await _save(cleanText, fireAt, const Recurrence.none());
  }

  void _insert(String suffix) {
    final base = _controller.text.trimRight();
    final next = base.isEmpty ? suffix : '$base $suffix';
    _controller.text = next;
    _controller.selection = TextSelection.collapsed(offset: next.length);
    ref.read(composeDraftProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(livePreviewProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: AppColors.mutedWhite),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Remind me to…', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                minLines: 1,
                maxLength: 500,
                style: AppTypography.display.copyWith(fontSize: 24),
                cursorColor: AppColors.shinyWhite,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'call mom in 2 hours',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
                onChanged: (v) =>
                    ref.read(composeDraftProvider.notifier).state = v,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Preview(preview: preview),
              const SizedBox(height: AppSpacing.xl),
              Text('Suggestions', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in const ['tonight', 'tomorrow 9am', 'every Monday'])
                    _Chip(label: s, onTap: () => _insert(s)),
                ],
              ),
              const Spacer(),
              _PrimaryAction(
                preview: preview,
                saving: _saving,
                onSave: _save,
                onPickTime: _pickManualTime,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.preview});
  final ParseOutcome preview;

  @override
  Widget build(BuildContext context) {
    final (icon, line, sub, color) = switch (preview) {
      ParseSuccess(:final reminder) => (
          Icons.arrow_forward,
          'fires ${formatRelative(reminder.fireAt)}',
          '${formatWhen(reminder.fireAt)}'
              '${reminder.recurrence.isRecurring ? ' · repeats' : ''}',
          AppColors.shortTermAccent,
        ),
      ParseNeedsTime() => (
          Icons.schedule,
          'Pick a time',
          'No time found in your text',
          AppColors.mutedWhite,
        ),
      ParseFailure(:final message) => (
          Icons.error_outline,
          message,
          '',
          AppColors.dangerRed,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.glassTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line, style: AppTypography.bodyMedium),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(sub, style: AppTypography.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.preview,
    required this.saving,
    required this.onSave,
    required this.onPickTime,
  });

  final ParseOutcome preview;
  final bool saving;
  final void Function(String text, DateTime fireAt, Recurrence recurrence) onSave;
  final void Function(String cleanText) onPickTime;

  @override
  Widget build(BuildContext context) {
    switch (preview) {
      case ParseSuccess(:final reminder):
        return GlassButton(
          label: 'Save reminder',
          filled: true,
          loading: saving,
          onPressed: () =>
              onSave(reminder.cleanText, reminder.fireAt, reminder.recurrence),
        );
      case ParseNeedsTime(:final cleanText):
        return GlassButton(
          label: 'Pick a time',
          onPressed: () => onPickTime(cleanText),
        );
      case ParseFailure():
        return const GlassButton(label: 'Save reminder', onPressed: null);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.glassTint,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(label, style: AppTypography.caption),
      ),
    );
  }
}
