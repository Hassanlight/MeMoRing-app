/// Owner remote controls, fetched from Supabase at startup:
///  • ads on/off across all users
///  • force-update gate (block old versions)
///
/// Fail-open: if the config can't be fetched (offline, no backend), ads keep
/// their normal behavior and no update gate is shown — the app never breaks.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:memoring/core/backend_config.dart';

/// Bump this by 1 every release (matches the build number in pubspec version).
const int kVersionCode = 3;

class RemoteConfig {
  static bool adsEnabled = true;
  static bool _updateRequired = false;
  static int _minVersionCode = 0;
  static String updateMessage =
      'A new version of Memoring is available. Please update to continue.';
  static String updateUrl = '';

  static Future<void> load() async {
    try {
      final uri = Uri.parse('$kSupabaseUrl/rest/v1/app_config?id=eq.1&select=*');
      final r = await http.get(uri, headers: {
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer $kSupabaseAnonKey',
      }).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final c = list.first as Map<String, dynamic>;
          adsEnabled = c['ads_enabled'] as bool? ?? true;
          _updateRequired = c['update_required'] as bool? ?? false;
          _minVersionCode = (c['min_version_code'] as num?)?.toInt() ?? 0;
          updateMessage = c['update_message'] as String? ?? updateMessage;
          updateUrl = c['update_url'] as String? ?? '';
        }
      }
    } on Object {
      // Fail open — keep safe defaults.
    }
  }

  /// True when the owner has forced an update or this build is below the
  /// required minimum version.
  static bool get mustUpdate =>
      _updateRequired || kVersionCode < _minVersionCode;
}
