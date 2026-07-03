/// Local app-lock PIN. Only a SHA-256 hash is stored (security.json) — the PIN
/// itself never touches disk. Unlock lasts until the app is fully closed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class PinStore {
  /// True once the user unlocked this session (resets on app restart).
  static bool sessionUnlocked = false;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/security.json');
  }

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('memoring:$pin')).toString();

  static Future<bool> hasPin() async {
    try {
      final f = await _file();
      return f.existsSync() &&
          (jsonDecode(await f.readAsString())
                  as Map<String, dynamic>)['pinHash'] !=
              null;
    } on Object {
      return false;
    }
  }

  static Future<void> setPin(String pin) async {
    final f = await _file();
    await f.writeAsString(jsonEncode({'pinHash': _hash(pin)}));
    sessionUnlocked = true;
  }

  static Future<void> removePin() async {
    try {
      final f = await _file();
      if (f.existsSync()) await f.delete();
    } on Object {
      // Best-effort.
    }
    sessionUnlocked = false;
  }

  static Future<bool> verify(String pin) async {
    try {
      final f = await _file();
      if (!f.existsSync()) return true;
      final stored = (jsonDecode(await f.readAsString())
          as Map<String, dynamic>)['pinHash'] as String?;
      final ok = stored == null || stored == _hash(pin);
      if (ok) sessionUnlocked = true;
      return ok;
    } on Object {
      return false;
    }
  }
}
