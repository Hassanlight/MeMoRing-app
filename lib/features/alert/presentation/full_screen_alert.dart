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
import 'package:memoring/features/alert/data/photo_verifier.dart';
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
  final _verifier = PhotoVerifier();

  String? _shotPath; // captured, not yet submitted
  bool _capturing = false;
  bool _autoOpened = false;
  bool _verifying = false;
  bool _verified = false;
  String _verifyNote = '';
  int _failedChecks = 0;

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
        imageQuality: 60,
        maxWidth: 1200,
      );
      if (shot == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      // Show the temp file instantly; copy to permanent storage only on Submit.
      if (mounted) {
        setState(() {
          _shotPath = shot.path;
          _capturing = false;
          _verifying = selfie; // mosque/mat check applies to prayer selfies
          _verified = !selfie;
          _verifyNote = '';
        });
      }
      if (selfie) {
        final check = await _verifier.checkMosqueOrPrayerMat(shot.path);
        if (mounted) {
          setState(() {
            _verifying = false;
            _verified = check.accepted;
            if (!check.accepted) {
              _failedChecks++;
              _verifyNote = check.seen.isEmpty
                  ? "Couldn't detect a mosque or prayer mat — retake."
                  : "Couldn't detect a mosque or prayer mat (saw: ${check.seen}). Retake.";
            }
          });
        }
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
      var saved = _shotPath;
      try {
        if (_shotPath != null) saved = await persistImage(_shotPath!);
      } catch (_) {
        // Keep the temp path if the copy fails — still better than nothing.
      }
      await controller.complete(reminder.copyWith(imagePath: () => saved));
      if (context.mounted) context.pop();
    }

    // High-intensity alerts cannot be escaped: back is blocked until the
    // confirmation photo is submitted. The ring continues regardless.
    return PopScope(
      canPop: !isHigh,
      child: Scaffold(
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
                          height: 220, fit: BoxFit.cover, cacheHeight: 440),
                    )
                  else if (reminder.imagePath != null &&
                      File(reminder.imagePath!).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      child: Image.file(File(reminder.imagePath!),
                          height: 200, fit: BoxFit.cover, cacheHeight: 400),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  // Big bright note: short messages get huge type.
                  Text(
                    reminder.text,
                    style: AppTypography.alert.copyWith(
                      fontSize: reminder.text.length <= 24
                          ? 56
                          : reminder.text.length <= 60
                              ? 44
                              : 34,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
    final canSubmit = !_verifying && (_verified || _failedChecks >= 2);
    return Column(
      children: [
        if (_verifying)
          Text('Checking photo…', style: AppTypography.caption)
        else if (!_verified && _verifyNote.isNotEmpty)
          Text(_verifyNote,
              style: AppTypography.caption
                  .copyWith(color: AppColors.dangerRed),
              textAlign: TextAlign.center)
        else if (_verified && isMuslim)
          Text('Looks good ✓', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.md),
        Row(
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
              child: GlassButton(
                label: !_verified && _failedChecks >= 2
                    ? 'Submit anyway'
                    : 'Submit',
                filled: true,
                loading: _verifying,
                onPressed: canSubmit ? submit : null,
              ),
            ),
          ],
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
