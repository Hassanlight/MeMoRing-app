/// The one button primitive. Every interactive press uses this so pressed,
/// disabled, and loading states are guaranteed everywhere — no dead taps.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';

class GlassButton extends StatefulWidget {
  const GlassButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.loading = false,
    this.danger = false,
    super.key,
  });

  /// Filled (high-emphasis) primary action vs. glass (secondary).
  final bool filled;
  final bool loading;
  final bool danger;
  final String label;

  /// Null disables the button (rendered at 40% opacity, no taps).
  final VoidCallback? onPressed;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final fg = widget.filled ? AppColors.matteBlack : AppColors.shinyWhite;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _pressed ? 0.85 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.filled ? AppColors.shinyWhite : AppColors.glassTintStrong,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: widget.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.shinyWhite,
                        ),
                      )
                    : Text(
                        widget.label,
                        style: AppTypography.bodyMedium.copyWith(
                          color: widget.danger ? AppColors.dangerRed : fg,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
