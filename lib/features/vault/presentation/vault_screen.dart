/// Vault — "where did I put it?" Snap a photo + one line; search it later.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/app/theme/app_spacing.dart';
import 'package:memoring/app/theme/app_typography.dart';
import 'package:memoring/core/image_store.dart';
import 'package:memoring/core/widgets/glass_button.dart';
import 'package:memoring/core/widgets/glass_card.dart';
import 'package:memoring/features/vault/data/vault_store.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  final _picker = ImagePicker();
  String? _pendingImage;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _snap(ImageSource source) async {
    final shot = await _picker.pickImage(
        source: source, imageQuality: 60, maxWidth: 1200);
    if (shot == null) return;
    final saved = await persistImage(shot.path);
    if (mounted) setState(() => _pendingImage = saved);
  }

  Future<void> _save() async {
    final text = _note.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    await ref
        .read(vaultProvider.notifier)
        .add(text.isEmpty ? 'Untitled' : text, _pendingImage);
    if (mounted) {
      setState(() => _pendingImage = null);
      _note.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(vaultProvider);
    final visible = _query.isEmpty
        ? items
        : items
            .where((i) => i.text.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.shinyWhite)),
        title: const Text('Vault', style: AppTypography.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            // Add a memory
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _note,
                    style: AppTypography.body,
                    cursorColor: AppColors.shinyWhite,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'e.g. Passport → black drawer, bedroom',
                      hintStyle: TextStyle(color: AppColors.mutedWhite),
                    ),
                  ),
                  if (_pendingImage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      child: Image.file(File(_pendingImage!),
                          height: 90, fit: BoxFit.cover, cacheHeight: 180),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _snap(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined,
                            color: AppColors.mutedWhite),
                        tooltip: 'Take photo',
                      ),
                      IconButton(
                        onPressed: () => _snap(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined,
                            color: AppColors.mutedWhite),
                        tooltip: 'From gallery',
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 120,
                        child: GlassButton(
                            label: 'Save', filled: true, onPressed: _save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Search
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _search,
                style: AppTypography.body,
                cursorColor: AppColors.shinyWhite,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppColors.mutedWhite),
                  hintText: 'Search — "passport"',
                  hintStyle: TextStyle(color: AppColors.mutedWhite),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  items.isEmpty
                      ? 'Save where things are — a photo and one line.\nFind them here forever.'
                      : 'Nothing matches "$_query".',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final i in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        if (i.imagePath != null &&
                            File(i.imagePath!).existsSync())
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.md),
                            child: Image.file(File(i.imagePath!),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                cacheWidth: 104),
                          )
                        else
                          const Icon(Icons.sticky_note_2_outlined,
                              color: AppColors.mutedWhite, size: 28),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                            child: Text(i.text, style: AppTypography.body)),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.mutedWhite),
                          onPressed: () =>
                              ref.read(vaultProvider.notifier).remove(i.id),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
