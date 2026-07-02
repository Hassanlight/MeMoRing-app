/// On-device photo verification for alarm dismissal.
///
/// Two independent gates, both fully offline (ML Kit):
/// 1. FACE — the photo must contain a real face (all confirmation selfies).
/// 2. SCENE — for Muslim prayer selfies, the frame must also look like a
///    mosque or a prayer carpet/mat (heuristic labels).
///
/// Engine failures FAIL OPEN (photo accepted) so a broken/unavailable model
/// can never trap the user with an alarm that won't stop. A photo the engine
/// *did* analyse and rejected does NOT stop the alarm.
library;

import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

final class PhotoCheck {
  const PhotoCheck({
    required this.faceOk,
    required this.sceneOk,
    required this.seen,
  });

  final bool faceOk;
  final bool sceneOk;

  /// Top labels the model saw — shown to the user when rejected.
  final String seen;

  bool get accepted => faceOk && sceneOk;
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

  /// Verifies a confirmation selfie. [requireMosque] adds the scene gate.
  Future<PhotoCheck> checkSelfie(
    String path, {
    required bool requireMosque,
  }) async {
    final input = InputImage.fromFile(File(path));

    // Gate 1 — a face must be present.
    var faceOk = false;
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.1,
      ),
    );
    try {
      final faces = await faceDetector.processImage(input);
      faceOk = faces.isNotEmpty;
    } on Object {
      faceOk = true; // engine broke — fail open, don't trap the user
    } finally {
      await faceDetector.close();
    }

    // Gate 2 — mosque / prayer-mat scene (prayer selfies only).
    var sceneOk = !requireMosque;
    var seen = '';
    if (requireMosque) {
      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.45),
      );
      try {
        final labels = await labeler.processImage(input);
        final names = labels.map((l) => l.label.toLowerCase()).toList();
        sceneOk = names.any((n) => _keywords.any((k) => n.contains(k)));
        seen = names.take(4).join(', ');
      } on Object {
        sceneOk = true; // engine broke — fail open
      } finally {
        await labeler.close();
      }
    }

    return PhotoCheck(faceOk: faceOk, sceneOk: sceneOk, seen: seen);
  }
}
