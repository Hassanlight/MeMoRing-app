/// Wraps private screens (Memories, Vault, Dashboard). If an app-lock PIN is
/// set and this session isn't unlocked yet, asks for the PIN first.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/security/pin_store.dart';
import 'package:memoring/core/widgets/glass_button.dart';

class PinGate extends StatefulWidget {
  const PinGate({required this.child, super.key});
  final Widget child;

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> {
  final _pin = TextEditingController();
  bool? _locked; // null = checking
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final has = await PinStore.hasPin();
    if (mounted) setState(() => _locked = has && !PinStore.sessionUnlocked);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _try() async {
    final ok = await PinStore.verify(_pin.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    } else {
      setState(() => _wrong = true);
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.mutedWhite)),
      );
    }
    if (!_locked!) return widget.child;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  size: 48, color: AppColors.shinyWhite),
              const SizedBox(height: AppSpacing.lg),
              Text('Enter your PIN', style: AppTypography.heading),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofocus: true,
                style: AppTypography.heading,
                cursorColor: AppColors.shinyWhite,
                onSubmitted: (_) => _try(),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: AppColors.mutedWhite),
                  filled: true,
                  fillColor: AppColors.glassTint,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusButton),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_wrong) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Wrong PIN — try again',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.dangerRed)),
              ],
              const SizedBox(height: AppSpacing.lg),
              GlassButton(label: 'Unlock', filled: true, onPressed: _try),
            ],
          ),
        ),
      ),
    );
  }
}
