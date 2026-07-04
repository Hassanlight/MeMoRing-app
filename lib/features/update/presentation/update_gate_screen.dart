/// Blocking "please update" screen shown when the owner forces an update
/// (or the build is below the required minimum) via the admin dashboard.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/remote_config.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateGateScreen extends StatelessWidget {
  const UpdateGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.matteBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 64, color: AppColors.shinyWhite),
              const SizedBox(height: AppSpacing.lg),
              Text('Update required', style: AppTypography.heading),
              const SizedBox(height: AppSpacing.md),
              Text(
                RemoteConfig.updateMessage,
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (RemoteConfig.updateUrl.isNotEmpty)
                GlassButton(
                  label: 'Update now',
                  filled: true,
                  onPressed: () => launchUrl(
                    Uri.parse(RemoteConfig.updateUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
