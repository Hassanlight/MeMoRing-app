/// Copies a picked image into the app's documents dir so it persists after the
/// picker's temp cache is cleared.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns the permanent on-device path of the stored copy of [tempPath].
Future<String> persistImage(String tempPath) async {
  final dir = await getApplicationDocumentsDirectory();
  final images = Directory('${dir.path}/images');
  if (!images.existsSync()) images.createSync(recursive: true);
  final ext = tempPath.contains('.') ? tempPath.split('.').last : 'jpg';
  final dest = '${images.path}/${_uuid.v4()}.$ext';
  await File(tempPath).copy(dest);
  return dest;
}
