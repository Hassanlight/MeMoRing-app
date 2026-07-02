/// First-run onboarding: name, age, religion → tailors which features appear.
/// Muslim users can opt into prayer reminders here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/onboarding/domain/user_profile.dart';
import 'package:memoring/features/onboarding/presentation/profile_providers.dart';
import 'package:memoring/features/prayer/presentation/prayer_providers.dart';
import 'package:memoring/features/reminders/domain/reminder.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  String _ageBand = '';
  Religion _religion = Religion.undisclosed;
  bool _prayer = false;
  ReminderIntensity _prayerIntensity = ReminderIntensity.medium;
  bool _saving = false;
  bool _granting = false;
  bool? _notifOk;
  bool? _camOk;
  bool? _micOk;

  static const _ageBands = ['Under 18', '18–30', '31–50', '50+'];

  bool get _allGranted =>
      (_notifOk ?? false) && (_camOk ?? false) && (_micOk ?? false);

  Future<void> _refreshPermissionStatus() async {
    final notif =
        await ref.read(notificationServiceProvider).notificationsAllowed();
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _notifOk = notif;
        _camOk = cam.isGranted;
        _micOk = mic.isGranted;
      });
    }
  }

  /// Request everything the app uses, one OS dialog after another, so nothing
  /// interrupts the user later.
  Future<void> _grantAll() async {
    setState(() => _granting = true);
    await ref.read(notificationServiceProvider).requestPermission();
    await Permission.camera.request();
    await Permission.microphone.request();
    await _refreshPermissionStatus();
    if (mounted) setState(() => _granting = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPermissionStatus());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Make sure every permission was offered before entering the app.
    if (!_allGranted && !_granting) {
      await _grantAll();
    }
    setState(() => _saving = true);
    final prayerOn = _religion == Religion.muslim && _prayer;
    final profile = UserProfile(
      name: _name.text.trim(),
      ageBand: _ageBand,
      religion: _religion,
      prayerReminders: prayerOn,
      prayerIntensity: _prayerIntensity,
    );
    await ref.read(profileRepositoryProvider).save(profile);
    ref.invalidate(profileProvider);
    await ref.read(prayerServiceProvider).sync(profile);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('Welcome to Memoring', style: AppTypography.display),
            const SizedBox(height: AppSpacing.sm),
            Text('A couple of quick questions so reminders fit you. This stays '
                'on your device.', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xl),

            Text('Your name (optional)', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _name,
                style: AppTypography.body,
                textCapitalization: TextCapitalization.words,
                cursorColor: AppColors.shinyWhite,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. Layal',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Age', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final band in _ageBands)
                  _Choice(
                    label: band,
                    selected: _ageBand == band,
                    onTap: () => setState(() => _ageBand = band),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Religion (optional — tailors features)',
                style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Choice(
                  label: 'Muslim',
                  selected: _religion == Religion.muslim,
                  onTap: () => setState(() => _religion = Religion.muslim),
                ),
                _Choice(
                  label: 'Other',
                  selected: _religion == Religion.other,
                  onTap: () => setState(() {
                    _religion = Religion.other;
                    _prayer = false;
                  }),
                ),
                _Choice(
                  label: 'Prefer not to say',
                  selected: _religion == Religion.undisclosed,
                  onTap: () => setState(() {
                    _religion = Religion.undisclosed;
                    _prayer = false;
                  }),
                ),
              ],
            ),

            if (_religion == Religion.muslim) ...[
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.mosque_outlined,
                        color: AppColors.mutedWhite, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Prayer time reminders (Fajr–Isha)',
                          style: AppTypography.bodyMedium),
                    ),
                    Switch(
                      value: _prayer,
                      activeColor: AppColors.shinyWhite,
                      onChanged: (v) => setState(() => _prayer = v),
                    ),
                  ],
                ),
              ),
              if (_prayer) ...[
                const SizedBox(height: AppSpacing.md),
                Text('How each prayer alert behaves', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Choice(
                      label: 'Ring once',
                      selected: _prayerIntensity == ReminderIntensity.low,
                      onTap: () => setState(
                          () => _prayerIntensity = ReminderIntensity.low),
                    ),
                    _Choice(
                      label: 'Keep ringing',
                      selected: _prayerIntensity == ReminderIntensity.medium,
                      onTap: () => setState(
                          () => _prayerIntensity = ReminderIntensity.medium),
                    ),
                    _Choice(
                      label: 'Selfie at mosque',
                      selected: _prayerIntensity == ReminderIntensity.high,
                      onTap: () => setState(
                          () => _prayerIntensity = ReminderIntensity.high),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.xl),
            Text('Permissions — grant once, works smoothly forever',
                style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  _PermRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Notifications & alarms',
                    sub: 'So reminders actually ring',
                    granted: _notifOk,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PermRow(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    sub: 'Photo reminders and selfie confirm',
                    granted: _camOk,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PermRow(
                    icon: Icons.mic_none,
                    label: 'Microphone',
                    sub: 'Speak reminders instead of typing',
                    granted: _micOk,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassButton(
                    label: _allGranted ? 'All set ✓' : 'Allow permissions',
                    loading: _granting,
                    onPressed: _allGranted ? null : _grantAll,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            GlassButton(
              label: 'Continue',
              filled: true,
              loading: _saving,
              onPressed: _finish,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.granted,
  });
  final IconData icon;
  final String label;
  final String sub;
  final bool? granted;

  @override
  Widget build(BuildContext context) {
    final (statusIcon, color) = switch (granted) {
      true => (Icons.check_circle, AppColors.shortTermAccent),
      false => (Icons.radio_button_unchecked, AppColors.mutedWhite),
      null => (Icons.radio_button_unchecked, AppColors.mutedWhite),
    };
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.mutedWhite),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodyMedium),
              Text(sub, style: AppTypography.caption),
            ],
          ),
        ),
        Icon(statusIcon, size: 18, color: color),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
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
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.shinyWhite : AppColors.mutedWhite,
          ),
        ),
      ),
    );
  }
}
