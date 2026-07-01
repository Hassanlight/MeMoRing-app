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
  bool _prayerSelfie = false;
  bool _saving = false;

  static const _ageBands = ['Under 18', '18–30', '31–50', '50+'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final prayerOn = _religion == Religion.muslim && _prayer;
    final profile = UserProfile(
      name: _name.text.trim(),
      ageBand: _ageBand,
      religion: _religion,
      prayerReminders: prayerOn,
      prayerSelfie: prayerOn && _prayerSelfie,
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
                Text('How to confirm each prayer', style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _Choice(
                      label: 'Just ring',
                      selected: !_prayerSelfie,
                      onTap: () => setState(() => _prayerSelfie = false),
                    ),
                    _Choice(
                      label: 'Selfie at mosque',
                      selected: _prayerSelfie,
                      onTap: () => setState(() => _prayerSelfie = true),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.xxl),
            GlassButton(
              label: 'Continue',
              filled: true,
              loading: _saving,
              onPressed: _finish,
            ),
          ],
        ),
      ),
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
