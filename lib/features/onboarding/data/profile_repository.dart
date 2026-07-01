/// Reads/writes the user profile as a local JSON file (offline, private).
library;

import 'dart:convert';
import 'dart:io';

import 'package:memoring/features/onboarding/domain/user_profile.dart';
import 'package:path_provider/path_provider.dart';

class ProfileRepository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profile.json');
  }

  Future<UserProfile?> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return null;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> save(UserProfile profile) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(profile.toJson()));
  }
}
