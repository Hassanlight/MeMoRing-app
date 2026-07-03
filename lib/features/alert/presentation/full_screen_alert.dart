/// Full-screen takeover shown when a reminder fires.
/// - low/medium: Snooze / Done / Dismiss (all stop the ringing).
/// - high: keeps ringing until the user takes a photo (a selfie at a mosque for
///   Muslim users) and taps Submit. Camera opens directly.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// The alert currently on screen — used to prevent the same reminder's alert
/// being pushed twice (notification tap + full-screen-intent launch).
String? activeAlertId;

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
  bool _faceOk = false;
  bool _submitted = false;
  String _verifyNote = '';
  int _failedChecks = 0;
  Timer? _vibrateTimer;

  // Wake level: math-to-dismiss.
  final _mathAnswer = TextEditingController();
  late int _mathA = 12 + Random().nextInt(38);
  late int _mathB = 3 + Random().nextInt(7);
  int _mathTries = 0;

  void _newProblem() {
    _mathA = 12 + Random().nextInt(38);
    _mathB = 3 + Random().nextInt(7);
    _mathAnswer.clear();
  }

  @override
  void initState() {
    super.initState();
    activeAlertId = widget.id;
  }

  @override
  void dispose() {
    if (activeAlertId == widget.id) activeAlertId = null;
    _vibrateTimer?.cancel();
    _mathAnswer.dispose();
    _anim.dispose();
    super.dispose();
  }

  /// Keeps vibrating until the selfie is submitted — muting the sound with the
  /// volume keys does not stop this.
  void _ensureVibration() {
    _vibrateTimer ??= Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (_submitted) {
        _vibrateTimer?.cancel();
        return;
      }
      HapticFeedback.vibrate();
    });
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
          _verifying = true; // every confirmation photo is verified
          _verified = false;
          _verifyNote = '';
        });
      }
      // Face is required for ALL selfie-level alarms; prayer selfies also
      // require the mosque / prayer-mat scene.
      final check =
          await _verifier.checkSelfie(shot.path, requireMosque: selfie);
      if (mounted) {
        setState(() {
          _verifying = false;
          _faceOk = check.faceOk;
          _verified = check.accepted;
          if (!check.accepted) {
            _failedChecks++;
            if (!check.faceOk) {
              _verifyNote =
                  "Couldn't see your face — take a clear selfie of yourself.";
            } else {
              _verifyNote = check.seen.isEmpty
                  ? "Couldn't detect a mosque or prayer mat — retake."
                  : "Couldn't detect a mosque or prayer mat (saw: ${check.seen}). Retake.";
            }
          }
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
    final isWake = reminder.intensity == ReminderIntensity.wake;
    final tough = isHigh || isWake; // inescapable levels
    final isMuslim = ref.watch(profileProvider).valueOrNull?.isMuslim ?? false;

    // Already confirmed (e.g. a stale notification was tapped after submit) or
    // already re-armed to a future time (recurring): never re-run the selfie
    // flow — show a calm done state instead.
    final notDueNow = reminder.effectiveFireAt
        .isAfter(DateTime.now().add(const Duration(minutes: 1)));
    if (reminder.isCompleted || _submitted || notDueNow) {
      _vibrateTimer?.cancel();
      return Scaffold(
        backgroundColor: AppColors.matteBlack,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    size: 64, color: AppColors.shortTermAccent),
                const SizedBox(height: AppSpacing.lg),
                Text('Already confirmed', style: AppTypography.heading),
                const SizedBox(height: AppSpacing.sm),
                Text(reminder.text, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: GlassButton(
                    label: 'Close',
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Ring + vibrate; photo levels open the camera straight away.
    if (tough) {
      _ensureVibration();
      if (isHigh && !_autoOpened) {
        _autoOpened = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _openCamera(isMuslim));
      }
    }

    Future<void> stopAndPop(Future<void> Function() action) async {
      await controller.stopAlert(reminder.id);
      await action();
      if (context.mounted) context.pop();
    }

    Future<void> submit() async {
      _submitted = true;
      _vibrateTimer?.cancel();
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

    // Tough alerts cannot be escaped: back is blocked until confirmed
    // (photo for high, math for wake). The ring continues regardless.
    return PopScope(
      canPop: !tough,
      child: Scaffold(
      backgroundColor: AppColors.matteBlack,
      body: SafeArea(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(
            CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
          ),
          child: FadeTransition(
            opacity: _anim,
            // Scrollable + min-height so the keyboard (Wake math input) can
            // never overflow the layout on small screens.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
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
                  else if (isWake)
                    _mathActions(controller, reminder, stopAndPop)
                  else
                    _ringActions(controller, reminder, stopAndPop),
                ],
              ),
                    ),
                  ),
                ),
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
    // A face is ALWAYS required — no bypass. The mosque/scene gate can be
    // bypassed only after 3 rejected attempts (heuristic model, e.g. an
    // unusual mosque angle), and even then only with a face in frame.
    final canSubmit =
        !_verifying && (_verified || (_faceOk && _failedChecks >= 3));
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
                label: !_verified && _faceOk && _failedChecks >= 3
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

  Widget _mathActions(
    RemindersController controller,
    Reminder reminder,
    Future<void> Function(Future<void> Function()) stopAndPop,
  ) {
    return Column(
      children: [
        Text(
          'Solve to stop the alarm',
          style: AppTypography.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('$_mathA × $_mathB = ?',
            style: AppTypography.heading, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _mathAnswer,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          style: AppTypography.heading,
          cursorColor: AppColors.shinyWhite,
          decoration: InputDecoration(
            hintText: '?',
            hintStyle: const TextStyle(color: AppColors.mutedWhite),
            filled: true,
            fillColor: AppColors.glassTint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_mathTries > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Not quite — try again ($_mathTries wrong)',
              style:
                  AppTypography.caption.copyWith(color: AppColors.dangerRed)),
        ],
        const SizedBox(height: AppSpacing.md),
        GlassButton(
          label: 'Stop alarm',
          filled: true,
          onPressed: () {
            final given = int.tryParse(_mathAnswer.text.trim());
            if (given == _mathA * _mathB) {
              _submitted = true;
              _vibrateTimer?.cancel();
              stopAndPop(() => controller.complete(reminder));
            } else {
              setState(() {
                _mathTries++;
                _newProblem();
              });
            }
          },
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
