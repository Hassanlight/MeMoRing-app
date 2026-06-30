// Tests for natural-language cancellation detection.
import 'package:flutter_test/flutter_test.dart';
import 'package:memoring/features/scheduler/data/cancellation_parser.dart';

void main() {
  test('detects cancel verb and extracts the subject', () {
    final r = detectCancellation('cancel the dentist reminder');
    expect(r, isNotNull);
    expect(r!.target, 'dentist');
  });

  test('handles delete / remove / forget synonyms', () {
    expect(detectCancellation('delete my standup'), isNotNull);
    expect(detectCancellation('remove call mom'), isNotNull);
    expect(detectCancellation('forget about the gym'), isNotNull);
  });

  test('ignores normal reminder text', () {
    expect(detectCancellation('call mom in 2 hours'), isNull);
    expect(detectCancellation('buy milk tomorrow'), isNull);
  });

  test('strips filler words from the target', () {
    expect(detectCancellation('please cancel that meeting')!.target, 'meeting');
  });
}
