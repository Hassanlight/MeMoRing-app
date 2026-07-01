/// Full-screen takeover shown when a reminder fires.
/// - low/medium: Snooze / Done / Dismiss (all stop the ringing).
/// - high: keeps ringing until the user takes a photo (a selfie at a mosque for
///   Muslim users) and taps Submit. Camera opens directly.
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
import 'package:memoring/features/onboarding/presentation/profile_providers.dart';
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

  String? _shotPath; // captured, not yet submitted
  bool _capturing = false;
  bool _autoOpened = false;

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

  Future<void> _openCamera(bool selfie) async {
    setState(() => _capturing = true);
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice:
            selfie ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 70,
      );
      if (shot == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final saved = await persistImage(shot.path);
      if (mounted) {
        setState(() {
          _shotPath = saved;
          _capturing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _find();
    if (reminder == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final controller = ref.read(remindersControllerProvider);
    final isHigh = reminder.intensity == ReminderIntensity.high;
    final isMuslim = ref.watch(profileProvider).valueOrNull?.isMuslim ?? false;

    // Ring + open the camera straight away for photo-confirm reminders.
    if (isHigh && !_autoOpened) {
      _autoOpened = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openCamera(isMuslim));
    }

    Future<void> stopAndPop(Future<void> Function() action) async {
      await controller.stopAlert(reminder.id);
      await action();
      if (context.mounted) context.pop();
    }

    Future<void> submit() async {
      await controller.stopAlert(reminder.id);
      await controller.complete(reminder.copyWith(imagePath: () => _shotPath));
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
                  if (_shotPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      child: Image.file(File(_shotPath!),
                          height: 220, fit: BoxFit.cover),
                    )
                  else if (reminder.imagePath != null &&
                      File(reminder.imagePath!).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      child: Image.file(File(reminder.imagePath!),
                          height: 200, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(reminder.text,
                      style: AppTypography.alert, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  Text(formatWhen(reminder.fireAt),
                      style: AppTypography.caption),
                  const Spacer(),
                  if (isHigh)
                    _photoActions(reminder, isMuslim, submit)
                  else
                    _ringActions(controller, reminder, stopAndPop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoActions(
    Reminder reminder,
    bool isMuslim,
    Future<void> Function() submit,
  ) {
    if (_shotPath == null) {
      return Column(
        children: [
          Text(
            isMuslim
                ? 'Take a selfie in front of a mosque to stop the alarm.'
                : 'Take a photo to confirm and stop the alarm.',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          GlassButton(
            label: 'Open camera',
            filled: true,
            loading: _capturing,
            onPressed: () => _openCamera(isMuslim),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            label: 'Retake',
            onPressed: () {
              setState(() => _shotPath = null);
              _openCamera(isMuslim);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: GlassButton(label: 'Submit', filled: true, onPressed: submit),
        ),
      ],
    );
  }

  Widget _ringActions(
    RemindersController controller,
    Reminder reminder,
    Future<void> Function(Future<void> Function()) stopAndPop,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GlassButton(
                label: 'Snooze',
                onPressed: () => stopAndPop(
                  () => controller.snooze(reminder, const Duration(minutes: 15)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: GlassButton(
                label: 'Done',
                filled: true,
                onPressed: () => stopAndPop(() => controller.complete(reminder)),
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
    );
  }
}
