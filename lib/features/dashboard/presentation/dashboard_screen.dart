/// Owner dashboard — everything about YOUR data, on YOUR device: storage
/// stats, app-lock PIN, and the nuclear wipe. There is no server side; nothing
/// here (or anywhere) leaves the phone.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/security/pin_store.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/reminders/presentation/reminders_controller.dart';
import 'package:memoring/features/vault/data/vault_store.dart';
import 'package:path_provider/path_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _photoCount = 0;
  double _photoMb = 0;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    var count = 0;
    var bytes = 0;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final images = Directory('${dir.path}/images');
      if (images.existsSync()) {
        for (final f in images.listSync().whereType<File>()) {
          count++;
          bytes += f.lengthSync();
        }
      }
    } on Object {
      // Stats are best-effort.
    }
    final hasPin = await PinStore.hasPin();
    if (mounted) {
      setState(() {
        _photoCount = count;
        _photoMb = bytes / 1048576;
        _hasPin = hasPin;
      });
    }
  }

  Future<String?> _askPin(String title) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceBlack,
        title: Text(title, style: AppTypography.bodyMedium),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: AppTypography.body,
          cursorColor: AppColors.shinyWhite,
          decoration: const InputDecoration(
              hintText: '4+ digits',
              hintStyle: TextStyle(color: AppColors.mutedWhite)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.mutedWhite))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save',
                  style: TextStyle(color: AppColors.shinyWhite))),
        ],
      ),
    );
    return (pin != null && pin.length >= 4) ? pin : null;
  }

  Future<void> _wipeAll() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceBlack,
        title: const Text('Erase everything?', style: AppTypography.bodyMedium),
        content: Text(
            'All reminders, photos, vault items and history will be deleted '
            'from this device. This cannot be undone.',
            style: AppTypography.caption),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.mutedWhite))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Erase all',
                  style: TextStyle(color: AppColors.dangerRed))),
        ],
      ),
    );
    if (sure != true) return;

    final repo = ref.read(reminderRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelAll();
    for (final r in await repo.getAll()) {
      await repo.remove(r.id);
    }
    final vault = ref.read(vaultProvider);
    for (final v in vault) {
      await ref.read(vaultProvider.notifier).remove(v.id);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final images = Directory('${dir.path}/images');
      if (images.existsSync()) images.deleteSync(recursive: true);
    } on Object {
      // Best-effort.
    }
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data erased from this device')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider).valueOrNull ?? const [];
    final active =
        reminders.where((r) => r.isActive && !r.isCompleted).length;
    final completed = reminders.where((r) => r.isCompleted).length;
    final vaultCount = ref.watch(vaultProvider).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite)),
        title: const Text('Dashboard', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text('Your data (all on this device)', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              _Stat(label: 'Active', value: '$active'),
              const SizedBox(width: AppSpacing.md),
              _Stat(label: 'Done', value: '$completed'),
              const SizedBox(width: AppSpacing.md),
              _Stat(label: 'Vault', value: '$vaultCount'),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              _Stat(label: 'Photos', value: '$_photoCount'),
              const SizedBox(width: AppSpacing.md),
              _Stat(
                  label: 'Photo storage',
                  value: '${_photoMb.toStringAsFixed(1)} MB'),
            ]),
            const SizedBox(height: AppSpacing.xl),

            Text('Security', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(_hasPin ? Icons.lock : Icons.lock_open,
                        color: _hasPin
                            ? AppColors.shortTermAccent
                            : AppColors.mutedWhite,
                        size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                          _hasPin
                              ? 'App lock is ON — PIN required for Memories, Vault and this dashboard'
                              : 'App lock is OFF — anyone with your phone can open your photos',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.shinyWhite)),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                    _SmallAction(
                      label: _hasPin ? 'Change PIN' : 'Set PIN',
                      onTap: () async {
                        final pin = await _askPin(
                            _hasPin ? 'New PIN' : 'Create a PIN (4+ digits)');
                        if (pin != null) {
                          await PinStore.setPin(pin);
                          await _refresh();
                        }
                      },
                    ),
                    if (_hasPin)
                      _SmallAction(
                        label: 'Remove PIN',
                        onTap: () async {
                          await PinStore.removePin();
                          await _refresh();
                        },
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                      'Photos are stored in Memoring\'s private sandbox — other '
                      'apps cannot read them, they are not in the gallery, and '
                      'system backups are disabled.',
                      style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('Danger zone', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.md),
            GlassCard(
              onTap: _wipeAll,
              child: const Row(children: [
                Icon(Icons.delete_forever_outlined,
                    color: AppColors.dangerRed, size: 20),
                SizedBox(width: AppSpacing.md),
                Text('Erase all data',
                    style: TextStyle(
                        color: AppColors.dangerRed,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.glassTint,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.heading),
        ]),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap});
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.glassTintStrong,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(label,
            style:
                AppTypography.caption.copyWith(color: AppColors.shinyWhite)),
      ),
    );
  }
}
