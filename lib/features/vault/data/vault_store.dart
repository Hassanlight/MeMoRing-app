/// The Vault — timeless "where did I put it?" notes with photos.
/// Stored as vault.json in app documents; photos in the shared images dir.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final class VaultItem {
  const VaultItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.imagePath,
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'] as String,
        text: json['text'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        imagePath: json['imagePath'] as String?,
      );

  final String id;
  final String text;
  final DateTime createdAt;
  final String? imagePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'imagePath': imagePath,
      };
}

class VaultStore extends Notifier<List<VaultItem>> {
  static const _uuid = Uuid();

  @override
  List<VaultItem> build() {
    unawaited(_load());
    return const [];
  }

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vault.json');
  }

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return;
      final raw = jsonDecode(await f.readAsString()) as List<dynamic>;
      state = [
        for (final e in raw) VaultItem.fromJson(e as Map<String, dynamic>)
      ];
    } on Object {
      // Corrupt file → keep empty rather than crash.
    }
  }

  Future<void> _persist() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode([for (final i in state) i.toJson()]));
    } on Object {
      // Best-effort.
    }
  }

  Future<void> add(String text, String? imagePath) async {
    state = [
      VaultItem(
          id: _uuid.v4(),
          text: text,
          createdAt: DateTime.now(),
          imagePath: imagePath),
      ...state,
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _persist();
  }
}

final vaultProvider =
    NotifierProvider<VaultStore, List<VaultItem>>(VaultStore.new);
