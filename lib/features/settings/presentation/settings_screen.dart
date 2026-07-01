/// Settings — notification diagnostics + tests, and the privacy promise.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/onboarding/domain/user_profile.dart';
import 'package:memoring/features/onboarding/presentation/profile_providers.dart';
import 'package:memoring/features/prayer/presentation/prayer_providers.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _notifsOn;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final on = await ref.read(notificationServiceProvider).notificationsAllowed();
    final profile = await ref.read(profileRepositoryProvider).load();
    if (mounted) {
      setState(() {
        _notifsOn = on;
        _profile = profile;
      });
    }
  }

  Future<void> _updateProfile(UserProfile updated) async {
    await ref.read(profileRepositoryProvider).save(updated);
    ref.invalidate(profileProvider);
    await ref.read(prayerServiceProvider).sync(updated);
    if (mounted) setState(() => _profile = updated);
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.read(notificationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite),
        ),
        title: const Text('Settings', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Notification status', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(label: 'Notifications allowed', value: _notifsOn),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _notifsOn == false
                        ? 'Notifications are off — nothing will ring. Tap "Grant '
                            'permissions" (or enable Memoring in system settings).'
                        : 'If a timed alert is late or silent: allow "Alarms & '
                            'reminders", turn off battery optimization for Memoring, '
                            'and make sure alarm volume is up.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _ActionTile(
              icon: Icons.verified_user_outlined,
              label: 'Grant permissions',
              onTap: () async {
                await notifications.requestPermission();
                await _refresh();
                _snack('Re-checked permissions');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionTile(
              icon: Icons.notifications_active_outlined,
              label: 'Test now (instant)',
              onTap: () async {
                await notifications.showNow();
                _snack('Sent an instant test notification');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionTile(
              icon: Icons.timer_outlined,
              label: 'Test in 5 seconds',
              onTap: () async {
                await notifications.scheduleTest();
                _snack('Test alert in 5s — lock or background the app');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionTile(
              icon: Icons.refresh,
              label: 'Re-check status',
              onTap: _refresh,
            ),

            if (_profile?.isMuslim ?? false) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Prayer reminders', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.sm),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mosque_outlined,
                            color: AppColors.mutedWhite, size: 20),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Text('Prayer times (Fajr–Isha)',
                              style: AppTypography.bodyMedium),
                        ),
                        Switch(
                          value: _profile!.prayerReminders,
                          activeColor: AppColors.shinyWhite,
                          onChanged: (v) => _updateProfile(
                            _profile!.copyWith(
                              prayerReminders: v,
                              prayerSelfie: v && _profile!.prayerSelfie,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_profile!.prayerReminders) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('Confirm each prayer', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _PrayerChoice(
                            label: 'Just ring',
                            selected: !_profile!.prayerSelfie,
                            onTap: () => _updateProfile(
                                _profile!.copyWith(prayerSelfie: false)),
                          ),
                          _PrayerChoice(
                            label: 'Selfie at mosque',
                            selected: _profile!.prayerSelfie,
                            onTap: () => _updateProfile(
                                _profile!.copyWith(prayerSelfie: true)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            const GlassCard(
              child: Row(
                children: [
                  Icon(Icons.palette_outlined,
                      color: AppColors.mutedWhite, size: 20),
                  SizedBox(width: AppSpacing.md),
                  Text('Appearance', style: AppTypography.bodyMedium),
                  Spacer(),
                  Text('Matte black', style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: AppColors.mutedWhite, size: 20),
                      SizedBox(width: AppSpacing.md),
                      Text('Privacy', style: AppTypography.bodyMedium),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your reminders never leave this device. No account, no cloud, '
                    'no tracking.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});
  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (value) {
      true => (Icons.check_circle, AppColors.shortTermAccent, 'On'),
      false => (Icons.cancel, AppColors.dangerRed, 'Off'),
      null => (Icons.help_outline, AppColors.mutedWhite, '—'),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTypography.bodyMedium),
        const Spacer(),
        Text(text, style: AppTypography.caption.copyWith(color: color)),
      ],
    );
  }
}

class _PrayerChoice extends StatelessWidget {
  const _PrayerChoice({
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
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.mutedWhite, size: 20),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.bodyMedium),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.mutedWhite),
        ],
      ),
    );
  }
}
