/// People — birthdays remembered the day BEFORE (when a gift is still possible)
/// and on the day itself. Yearly, forever, offline.
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

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _name = TextEditingController();
  DateTime? _birthday;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DateTime _nextOccurrence(int month, int day, int hour) {
    final now = DateTime.now();
    var c = DateTime(now.year, month, day, hour);
    if (!c.isAfter(now)) c = DateTime(now.year + 1, month, day, hour);
    return c;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final bday = _birthday;
    if (name.isEmpty || bday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a name and pick the birthday')));
      return;
    }
    setState(() => _saving = true);
    final ctrl = ref.read(remindersControllerProvider);
    final slug = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');

    // Day-of, 9am.
    await ctrl.create(
      id: 'person_${slug}_day',
      text: "🎂 $name's birthday today — wish them!",
      fireAt: _nextOccurrence(bday.month, bday.day, 9),
      recurrence: const Recurrence(RecurrenceType.yearly),
      intensity: ReminderIntensity.medium,
    );
    // Evening before, 7pm — when a gift is still possible. If that evening has
    // already passed (birthday is today/tomorrow), start from next year.
    final dayOf = _nextOccurrence(bday.month, bday.day, 19);
    var eve = dayOf.subtract(const Duration(days: 1));
    if (!eve.isAfter(DateTime.now())) {
      eve = DateTime(eve.year + 1, eve.month, eve.day, 19);
    }
    await ctrl.create(
      id: 'person_${slug}_eve',
      text: "Tomorrow is $name's birthday — get something today 🎁",
      fireAt: eve,
      recurrence: const Recurrence(RecurrenceType.yearly),
      intensity: ReminderIntensity.medium,
    );

    if (mounted) {
      setState(() {
        _saving = false;
        _birthday = null;
      });
      _name.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name added — you'll never miss it ✓")));
    }
  }

  Future<void> _remove(String slug, String name) async {
    final ctrl = ref.read(remindersControllerProvider);
    await ctrl.delete('person_${slug}_day');
    await ctrl.delete('person_${slug}_eve');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(remindersProvider).valueOrNull ?? const [];
    // One row per person (from the _day reminder).
    final people = all
        .where((r) => r.id.startsWith('person_') && r.id.endsWith('_day'))
        .toList()
      ..sort((a, b) => a.fireAt.compareTo(b.fireAt));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite)),
        title: const Text('People', style: AppTypography.heading),
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
                  hintText: 'Name — e.g. Fatima',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1930),
                  lastDate: DateTime(now.year, 12, 31),
                  initialDate: DateTime(now.year, now.month, now.day),
                  helpText: 'Their birthday (year optional)',
                );
                if (d != null) setState(() => _birthday = d);
              },
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    _birthday == null
                        ? 'Pick the birthday'
                        : 'Birthday: ${_birthday!.day}/${_birthday!.month}',
                    style: AppTypography.bodyMedium,
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.mutedWhite),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassButton(
                label: 'Remember this person',
                filled: true,
                loading: _saving,
                onPressed: _save),
            const SizedBox(height: AppSpacing.sm),
            Text(
                "You'll be reminded the evening before (gift time) and on the day.",
                style: AppTypography.caption,
                textAlign: TextAlign.center),
            if (people.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Remembered people', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              for (final p in people)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            color: AppColors.longTermAccent, size: 18),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '${p.text.replaceAll("🎂 ", "").replaceAll("'s birthday today — wish them!", "")} · ${p.fireAt.day}/${p.fireAt.month}',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.shinyWhite),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.mutedWhite),
                          onPressed: () => _remove(
                              p.id.substring(7, p.id.length - 4),
                              p.text
                                  .replaceAll('🎂 ', '')
                                  .split("'s birthday")
                                  .first),
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
