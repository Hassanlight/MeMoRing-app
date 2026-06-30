/// Spacing, radius, and blur tokens (CLAUDE.md §3). Never use magic numbers.
library;

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double screen = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radiusCard = 24;
  static const double radiusButton = 16;
  static const double radiusSheet = 28;
  static const double radiusPill = 999;

  static const double glassBlur = 20;
  static const double sheetBlur = 24;
}
