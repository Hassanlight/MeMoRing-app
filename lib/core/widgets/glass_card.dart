/// Frosted glass surface layered over matte black (CLAUDE.md §3).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppSpacing.radiusCard,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSpacing.glassBlur,
          sigmaY: AppSpacing.glassBlur,
        ),
        child: Material(
          color: AppColors.glassTint,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.glassTintStrong,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
