/// Color tokens — single source of truth (CLAUDE.md §3). No raw hex elsewhere.
library;

import 'package:flutter/widgets.dart';

abstract final class AppColors {
  static const Color matteBlack = Color(0xFF0A0A0B);
  static const Color surfaceBlack = Color(0xFF141416);
  static const Color glassTint = Color(0x14FFFFFF); // 8% white
  static const Color glassTintStrong = Color(0x1FFFFFFF); // 12% white
  static const Color hairline = Color(0x1AFFFFFF); // 10% white
  static const Color shinyWhite = Color(0xFFFAFAFA);
  static const Color mutedWhite = Color(0xFFA0A0A8);
  static const Color accent = Color(0xFFE8E8EA);
  static const Color shortTermAccent = Color(0xFF7DD3FC);
  static const Color longTermAccent = Color(0xFFC4B5FD);
  static const Color dangerRed = Color(0xFFFF453A);
  static const Color shadow = Color(0x66000000); // black 40%
}
