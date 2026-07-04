/// Shows the newest owner-pushed announcement/promo at the top of the chat.
/// Dismissible; the dismissed id is remembered so it won't reappear.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/telemetry.dart';
import 'package:path_provider/path_provider.dart';

class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  ({int id, String? title, String body, String? actionUrl})? _ann;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _seenFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/announce_seen.txt');
  }

  Future<void> _load() async {
    final ann = await Telemetry.latestAnnouncement();
    if (ann == null) return;
    try {
      final f = await _seenFile();
      final seen = f.existsSync() ? f.readAsStringSync().trim() : '';
      if (seen == ann.id.toString()) return; // already dismissed
    } on Object {
      // ignore
    }
    if (mounted) setState(() => _ann = ann);
  }

  Future<void> _dismiss() async {
    final id = _ann?.id;
    if (mounted) setState(() => _ann = null);
    if (id != null) {
      try {
        (await _seenFile()).writeAsStringSync(id.toString());
      } on Object {
        // ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ann = _ann;
    if (ann == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.glassTintStrong,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined,
              color: AppColors.longTermAccent, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ann.title != null && ann.title!.isNotEmpty) ...[
                  Text(ann.title!, style: AppTypography.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(ann.body, style: AppTypography.caption),
              ],
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
            child: const Icon(Icons.close,
                color: AppColors.mutedWhite, size: 18),
          ),
        ],
      ),
    );
  }
}
