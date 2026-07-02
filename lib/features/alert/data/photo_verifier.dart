/// Best-effort on-device check that a confirmation photo shows a mosque or a
/// prayer carpet/mat. Uses ML Kit's offline image labeler (general labels), so
/// it is heuristic — and it FAILS OPEN: if verification itself errors (e.g.
/// model unavailable), the photo is accepted rather than trapping the user
/// with an alarm they cannot stop.
library;

import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

final class PhotoCheck {
  const PhotoCheck({required this.accepted, required this.seen});
  final bool accepted;

  /// Top labels the model saw — shown to the user when rejected.
  final String seen;
}

class PhotoVerifier {
  // General ML Kit labels that plausibly indicate a mosque exterior/interior
  // or a prayer carpet/mat.
  static const List<String> _keywords = [
    'mosque',
    'dome',
    'place of worship',
    'temple',
    'building',
    'architecture',
    'monument',
    'carpet',
    'rug',
    'mat',
    'flooring',
    'textile',
    'pattern',
    'prayer',
  ];

  Future<PhotoCheck> checkMosqueOrPrayerMat(String path) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.45),
    );
    try {
      final labels =
          await labeler.processImage(InputImage.fromFile(File(path)));
      final names = labels.map((l) => l.label.toLowerCase()).toList();
      final accepted =
          names.any((n) => _keywords.any((k) => n.contains(k)));
      return PhotoCheck(accepted: accepted, seen: names.take(4).join(', '));
    } on Object {
      // Fail open — never block dismissal because the checker broke.
      return const PhotoCheck(accepted: true, seen: '');
    } finally {
      await labeler.close();
    }
  }
}
