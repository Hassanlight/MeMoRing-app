/// Assembles the tokens into a dark [ThemeData].
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.matteBlack,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.matteBlack,
        primary: AppColors.shinyWhite,
        secondary: AppColors.accent,
        error: AppColors.dangerRed,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.shinyWhite,
        displayColor: AppColors.shinyWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.matteBlack,
        elevation: 0,
        titleTextStyle: AppTypography.title,
      ),
      splashColor: AppColors.glassTint,
      highlightColor: AppColors.glassTint,
    );
  }
}
