/// Makes owner-pushed announcements impossible to miss. Checked when the app
/// opens and every few minutes while it stays open; an unseen announcement
/// takes over the screen as a dialog wherever the user currently is, and also
/// lands in the notification shade. Dismissing writes the id to
/// announce_seen.txt (shared with the chat banner) so it never reappears.
/// Critical flows (alarm alert, onboarding, update gate) are never interrupted
/// — the announcement stays unseen and retries on the next poll.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memoring/app/router/app_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/telemetry.dart';
import 'package:memoring/features/alert/presentation/full_screen_alert.dart';
import 'package:memoring/shared/services/notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class AnnouncementCenter {
  /// Reserved plain-notification id (reminder alarms use their own ids).
  static const int _notificationId = 990030;

  static bool _dialogUp = false;
  static int? _notifiedId;

  /// Call once after the UI is up: checks immediately, then keeps polling.
  static void start(NotificationService notifications) {
    unawaited(check(notifications));
    Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(check(notifications)),
    );
  }

  static Future<File> _seenFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/announce_seen.txt');
  }

  static Future<void> check(NotificationService notifications) async {
    if (_dialogUp) return;
    final ann = await Telemetry.latestAnnouncement();
    if (ann == null) return;
    try {
      final f = await _seenFile();
      final seen = f.existsSync() ? f.readAsStringSync().trim() : '';
      if (seen == ann.id.toString()) return;
    } on Object {
      // Unreadable seen-file → treat as unseen.
    }

    // Shade notification, once per announcement per app run — covers the app
    // being in the background when the poll lands.
    if (_notifiedId != ann.id) {
      _notifiedId = ann.id;
      try {
        await notifications.schedulePlain(
          id: _notificationId,
          title: (ann.title ?? '').isNotEmpty ? ann.title! : 'Memoring',
          body: ann.body,
          when: DateTime.now().add(const Duration(seconds: 2)),
        );
      } on Object {
        // Best-effort; the dialog below is the guaranteed surface.
      }
    }

    // Never interrupt an alarm, onboarding, or the forced-update gate.
    String location = '';
    try {
      location = appRouter.routerDelegate.currentConfiguration.uri.toString();
    } on Object {
      // Router not ready — retry on the next poll.
      return;
    }
    if (activeAlertId != null ||
        location.startsWith('/alert') ||
        location.startsWith('/onboarding') ||
        location.startsWith('/update')) {
      return;
    }

    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    _dialogUp = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AnnouncementDialog(ann: ann),
      );
      try {
        (await _seenFile()).writeAsStringSync(ann.id.toString());
      } on Object {
        // If the write fails the dialog may reappear next run — acceptable.
      }
    } finally {
      _dialogUp = false;
    }
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.ann});

  final ({int id, String? title, String body, String? actionUrl}) ann;

  @override
  Widget build(BuildContext context) {
    final url = ann.actionUrl;
    return Dialog(
      backgroundColor: AppColors.surfaceBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_outlined,
                color: AppColors.longTermAccent, size: 32),
            const SizedBox(height: AppSpacing.md),
            if ((ann.title ?? '').isNotEmpty) ...[
              Text(ann.title!, style: AppTypography.heading),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(ann.body, style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (url != null && url.isNotEmpty) ...[
                  TextButton(
                    onPressed: () => unawaited(launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    )),
                    child: const Text('Open link',
                        style: TextStyle(color: AppColors.shortTermAccent)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.shinyWhite,
                    foregroundColor: AppColors.matteBlack,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
