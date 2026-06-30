// Tests for the intelligence layer. `now` is fixed so every rule is deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:memoring/features/reminders/domain/recurrence.dart';
import 'package:memoring/features/scheduler/domain/parsed_reminder.dart';
import 'package:memoring/features/scheduler/data/rule_based_time_intent_parser.dart';

void main() {
  const parser = RuleBasedTimeIntentParser();
  // 2026-06-30 12:00 (noon).
  final now = DateTime(2026, 6, 30, 12);

  ParsedReminder ok(String input) {
    final r = parser.parse(input, now: now);
    expect(r, isA<ParseSuccess>(), reason: 'expected success for "$input"');
    return (r as ParseSuccess).reminder;
  }

  group('relative durations', () {
    test('in 2 hours', () {
      final r = ok('call mom in 2 hours');
      expect(r.fireAt, DateTime(2026, 6, 30, 14));
      expect(r.cleanText, 'call mom');
      expect(r.recurrence.type, RecurrenceType.none);
    });

    test('in 10 minutes', () {
      expect(ok('stretch in 10 minutes').fireAt, DateTime(2026, 6, 30, 12, 10));
    });

    test('in 3 days', () {
      expect(ok('water plants in 3 days').fireAt, DateTime(2026, 7, 3, 12));
    });

    test('in 8 months classifies long-term', () {
      final r = ok('renew passport in 8 months');
      expect(r.fireAt.year, 2027);
      expect(r.fireAt.month, 2); // June + 8 = Feb next year
    });

    test('in an hour', () {
      expect(ok('coffee in an hour').fireAt, DateTime(2026, 6, 30, 13));
    });
  });

  group('named days', () {
    test('tomorrow 9am strips both phrases', () {
      final r = ok('submit report tomorrow 9am');
      expect(r.fireAt, DateTime(2026, 7, 1, 9));
      expect(r.cleanText, 'submit report');
    });

    test('tonight is 8pm today', () {
      expect(ok('gym tonight').fireAt, DateTime(2026, 6, 30, 20));
    });

    test('next friday is a future friday at 9am', () {
      final r = ok('demo next friday');
      expect(r.fireAt.weekday, DateTime.friday);
      expect(r.fireAt.hour, 9);
      expect(r.fireAt.isAfter(now), isTrue);
    });

    test('bare weekday rolls forward', () {
      final r = ok('call vendor monday');
      expect(r.fireAt.weekday, DateTime.monday);
      expect(r.fireAt.isAfter(now), isTrue);
    });
  });

  group('absolute dates', () {
    test('on december 25 this year at 9am', () {
      final r = ok('gifts on december 25');
      expect(r.fireAt, DateTime(2026, 12, 25, 9));
    });

    test('dec 25 at noon', () {
      expect(ok('lunch dec 25 at noon').fireAt, DateTime(2026, 12, 25, 12));
    });

    test('past date rolls to next year', () {
      final r = ok('taxes on june 30'); // 9am today already passed
      expect(r.fireAt.year, 2027);
      expect(r.fireAt.month, 6);
      expect(r.fireAt.day, 30);
    });
  });

  group('time of day', () {
    test('at 5 picks the next upcoming 5 oclock', () {
      // now is noon → today 17:00 is the soonest 5.
      expect(ok('meeting at 5').fireAt, DateTime(2026, 6, 30, 17));
    });
  });

  group('recurrence', () {
    test('daily', () {
      final r = ok('vitamins daily');
      expect(r.recurrence.type, RecurrenceType.daily);
      expect(r.fireAt.isAfter(now), isTrue);
    });

    test('every monday at 9am', () {
      final r = ok('standup every monday at 9am');
      expect(r.recurrence.type, RecurrenceType.weekly);
      expect(r.recurrence.weekday, DateTime.monday);
      expect(r.fireAt.weekday, DateTime.monday);
      expect(r.fireAt.hour, 9);
      expect(r.cleanText, 'standup');
    });

    test('monthly', () {
      expect(ok('rent monthly').recurrence.type, RecurrenceType.monthly);
    });

    test('every year on june 30', () {
      final r = ok('anniversary every year on june 30');
      expect(r.recurrence.type, RecurrenceType.yearly);
      expect(r.fireAt.month, 6);
      expect(r.fireAt.day, 30);
    });
  });

  group('cleanup + edge cases', () {
    test('strips leading "remind me to"', () {
      expect(ok('remind me to call mom tomorrow at 9am').cleanText, 'call mom');
    });

    test('no time → needs manual time, text preserved', () {
      final r = parser.parse('buy milk', now: now);
      expect(r, isA<ParseNeedsTime>());
      expect((r as ParseNeedsTime).cleanText, 'buy milk');
    });

    test('empty input is rejected', () {
      final r = parser.parse('   ', now: now);
      expect(r, isA<ParseFailure>());
      expect((r as ParseFailure).reason, ParseFailureReason.empty);
    });

    test('over-long input is rejected', () {
      final r = parser.parse('x' * 600, now: now);
      expect((r as ParseFailure).reason, ParseFailureReason.tooLong);
    });

    test('a computed past time is rejected', () {
      final r = parser.parse('thing today at 9am', now: now); // 9am < noon
      expect(r, isA<ParseFailure>());
      expect((r as ParseFailure).reason, ParseFailureReason.pastTime);
    });
  });
}
