/// Full-screen takeover shown when a reminder fires.
/// - low/medium: Snooze / Done / Dismiss (all stop the ringing).
/// - high: can ONLY be dismissed by taking a selfie to confirm.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/image_store.dart';
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
  final _picker = ImagePicker();
  bool _capturing = false;

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
    final isHigh = reminder.intensity == ReminderIntensity.high;

    Future<void> stopAndPop(Future<void> Function() action) async {
      await controller.stopAlert(reminder.id);
      await action();
      if (context.mounted) context.pop();
    }

    Future<void> takeSelfie() async {
      setState(() => _capturing = true);
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
      );
      if (shot == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final saved = await persistImage(shot.path);
      await controller.stopAlert(reminder.id);
      await controller.complete(reminder.copyWith(imagePath: () => saved));
      if (context.mounted) context.pop();
    }

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
                  if (reminder.imagePath != null &&
                      File(reminder.imagePath!).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      child: Image.file(
                        File(reminder.imagePath!),
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  Text(
                    reminder.text,
                    style: AppTypography.alert,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(formatWhen(reminder.fireAt), style: AppTypography.caption),
                  const Spacer(),
                  if (isHigh) ...[
                    Text(
                      'Take a selfie to confirm and stop the alarm.',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GlassButton(
                      label: 'Take selfie to dismiss',
                      filled: true,
                      loading: _capturing,
                      onPressed: takeSelfie,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Snooze',
                            onPressed: () => stopAndPop(
                              () => controller.snooze(
                                  reminder, const Duration(minutes: 15)),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: GlassButton(
                            label: 'Done',
                            filled: true,
                            onPressed: () =>
                                stopAndPop(() => controller.complete(reminder)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => stopAndPop(() async {}),
                      child: const Text('Dismiss',
                          style: TextStyle(color: AppColors.mutedWhite)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
