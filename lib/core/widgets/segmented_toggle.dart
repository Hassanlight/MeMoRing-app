/// Glass segmented control (Short-term ⇄ Long-term). Animated active pill.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';

class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.glassTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? AppColors.glassTintStrong : null,
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Center(
                    child: Text(
                      segments[i],
                      style: AppTypography.caption.copyWith(
                        color: i == selectedIndex
                            ? AppColors.shinyWhite
                            : AppColors.mutedWhite,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
