/// Medicine — daily dose reminders with optional photo proof (the alarm only
/// stops after a photo of the pill in hand).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key});

  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  final _name = TextEditingController();
  final Set<TimeOfDay> _times = {const TimeOfDay(hour: 8, minute: 0)};
  bool _photoProof = false;
  bool _saving = false;

  static const _presets = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the medicine name and pick at least one time')));
      return;
    }
    setState(() => _saving = true);
    final ctrl = ref.read(remindersControllerProvider);
    final now = DateTime.now();
    final slug = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
    for (final t in _times) {
      var fireAt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (!fireAt.isAfter(now)) fireAt = fireAt.add(const Duration(days: 1));
      await ctrl.create(
        id: 'med_${slug}_${t.hour}${t.minute.toString().padLeft(2, '0')}',
        text: '💊 Take $name',
        fireAt: fireAt,
        recurrence: const Recurrence(RecurrenceType.daily),
        intensity:
            _photoProof ? ReminderIntensity.high : ReminderIntensity.medium,
      );
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$name scheduled daily at ${_times.length} time(s) ✓')));
      _name.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(remindersProvider).valueOrNull ?? const [];
    final meds = all
        .where((r) => r.id.startsWith('med_') && !r.isCompleted)
        .toList()
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite)),
        title: const Text('Medicine', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _name,
                style: AppTypography.body,
                textCapitalization: TextCapitalization.words,
                cursorColor: AppColors.shinyWhite,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Medicine name — e.g. Panadol',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Times each day', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in _presets)
                  _TimeChip(
                    label: _fmt(t),
                    selected: _times.contains(t),
                    onTap: () => setState(() =>
                        _times.contains(t) ? _times.remove(t) : _times.add(t)),
                  ),
                _TimeChip(
                  label: '+ custom',
                  selected: false,
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (t != null) setState(() => _times.add(t));
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text('Photo proof — alarm stops only after a photo',
                        style: AppTypography.bodyMedium),
                  ),
                  Switch(
                    value: _photoProof,
                    activeColor: AppColors.shinyWhite,
                    onChanged: (v) => setState(() => _photoProof = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
                label: 'Set medicine reminders',
                filled: true,
                loading: _saving,
                onPressed: _save),
            if (meds.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Active doses', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              for (final m in meds)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () => context.push('/reminder/${m.id}'),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_outlined,
                            color: AppColors.mutedWhite, size: 18),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                            child: Text(m.text,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.shinyWhite))),
                        Text(
                            TimeOfDay.fromDateTime(m.fireAt).format(context),
                            style: AppTypography.caption),
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

class _TimeChip extends StatelessWidget {
  const _TimeChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.glassTintStrong : AppColors.glassTint,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(label,
            style: AppTypography.caption.copyWith(
                color:
                    selected ? AppColors.shinyWhite : AppColors.mutedWhite)),
      ),
    );
  }
}

