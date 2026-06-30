/// Type scale (CLAUDE.md §3). SF Pro feel via the platform default; max 2
/// weights per screen (regular 400, medium 500/600 for headings).
library;

import 'package:flutter/widgets.dart';
import 'package:memoring/app/theme/app_colors.dart';

abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.15,
    color: AppColors.shinyWhite,
  );
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.shinyWhite,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.shinyWhite,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.shinyWhite,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.shinyWhite,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedWhite,
  );
  static const TextStyle alert = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.shinyWhite,
  );
}
