/// Anonymous telemetry, feedback, and remote announcements over Supabase REST.
///
/// PRIVACY: sends ONLY an anonymous random install id + non-personal event
/// names (e.g. "app_open", "reminder_created"). Never sends reminder text,
/// photos, names, or any personal content. Fully opt-out-able. Fails silently
/// and never blocks the UI (fire-and-forget, offline-safe).
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:memoring/core/backend_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class Telemetry {
  static String? _installId;

  /// User opt-out (default on). Loaded at startup; toggled from the Dashboard.
  static bool enabled = true;

  static Future<File> _flagFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/telemetry.txt');
  }

  static Future<void> loadPreference() async {
    try {
      final f = await _flagFile();
      if (f.existsSync()) enabled = f.readAsStringSync().trim() != '0';
    } on Object {
      enabled = true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      (await _flagFile()).writeAsStringSync(value ? '1' : '0');
    } on Object {
      // Best-effort.
    }
  }

  static Future<String> installId() async {
    if (_installId != null) return _installId!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/install_id.txt');
      if (f.existsSync()) _installId = f.readAsStringSync().trim();
      if (_installId == null || _installId!.isEmpty) {
        _installId = const Uuid().v4();
        f.writeAsStringSync(_installId!);
      }
    } on Object {
      _installId ??= const Uuid().v4();
    }
    return _installId!;
  }

  static Map<String, String> get _headers => {
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer $kSupabaseAnonKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      };

  /// Records a non-personal usage event. Safe to call anywhere.
  static Future<void> log(String name, {Map<String, dynamic>? props}) async {
    if (!enabled) return;
    try {
      final id = await installId();
      await http
          .post(
            Uri.parse('$kSupabaseUrl/rest/v1/events'),
            headers: _headers,
            body: jsonEncode({
              'install_id': id,
              'name': name,
              'props': props ?? const {},
              'app_version': kAppVersion,
              'platform': Platform.operatingSystem,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } on Object {
      // Offline / blocked / any error → ignore. Telemetry never affects UX.
    }
  }

  /// Submits user feedback. Returns whether it reached the server.
  static Future<bool> sendFeedback(
    String message, {
    int? rating,
    String? contact,
  }) async {
    try {
      final id = await installId();
      final r = await http
          .post(
            Uri.parse('$kSupabaseUrl/rest/v1/feedback'),
            headers: _headers,
            body: jsonEncode({
              'install_id': id,
              'message': message,
              'rating': rating,
              'contact': contact,
              'app_version': kAppVersion,
            }),
          )
          .timeout(const Duration(seconds: 12));
      return r.statusCode >= 200 && r.statusCode < 300;
    } on Object {
      return false;
    }
  }

  /// Fetches the newest active announcement (owner-pushed message/promo), or null.
  static Future<({int id, String? title, String body, String? actionUrl})?>
      latestAnnouncement() async {
    try {
      final r = await http.get(
        Uri.parse(
            '$kSupabaseUrl/rest/v1/announcements?active=eq.true&order=created_at.desc&limit=1'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Authorization': 'Bearer $kSupabaseAnonKey',
        },
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final a = list.first as Map<String, dynamic>;
          return (
            id: a['id'] as int,
            title: a['title'] as String?,
            body: a['body'] as String,
            actionUrl: a['action_url'] as String?,
          );
        }
      }
    } on Object {
      // ignore
    }
    return null;
  }
}
