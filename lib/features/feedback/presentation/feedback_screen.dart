/// Send feedback — writes to the backend so the owner sees it in the dashboard.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/telemetry.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/core/widgets/glass_card.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  int _rating = 0;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final ok = await Telemetry.sendFeedback(
      _message.text.trim(),
      rating: _rating == 0 ? null : _rating,
      contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Thank you! Your feedback was sent.'
          : "Couldn't send — check your connection and try again."),
    ));
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite),
        ),
        title: const Text('Send feedback', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('How would you rate Memoring?', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating ? Icons.star : Icons.star_border,
                      color: i <= _rating
                          ? AppColors.longTermAccent
                          : AppColors.mutedWhite,
                      size: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Your message', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: TextField(
                controller: _message,
                maxLines: 5,
                maxLength: 1000,
                style: AppTypography.body,
                cursorColor: AppColors.shinyWhite,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'Tell us what you love or what to improve…',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Email (optional — if you want a reply)',
                style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _contact,
                keyboardType: TextInputType.emailAddress,
                style: AppTypography.body,
                cursorColor: AppColors.shinyWhite,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'you@example.com',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
              label: 'Send feedback',
              filled: true,
              loading: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
