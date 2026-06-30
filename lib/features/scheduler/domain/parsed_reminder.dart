/// The output of the intelligence layer: what + when, or why not.
library;

import 'package:memoring/features/reminders/domain/recurrence.dart';

/// A successfully understood reminder. [fireAt] is local wall-clock time.
final class ParsedReminder {
  const ParsedReminder({
    required this.cleanText,
    required this.fireAt,
    required this.recurrence,
  });

  final String cleanText;
  final DateTime fireAt;
  final Recurrence recurrence;
}

/// Why a parse could not produce a scheduled reminder.
enum ParseFailureReason { empty, tooLong, pastTime }

/// The result of [TimeIntentParser.parse] — a closed set of outcomes so the UI
/// must handle every case explicitly (no silent guessing).
sealed class ParseOutcome {
  const ParseOutcome();
}

/// Text understood with a concrete time.
final class ParseSuccess extends ParseOutcome {
  const ParseSuccess(this.reminder);
  final ParsedReminder reminder;
}

/// Text had no parseable time — the UI must show a time picker, never guess.
final class ParseNeedsTime extends ParseOutcome {
  const ParseNeedsTime(this.cleanText);
  final String cleanText;
}

/// Input rejected (empty, too long, or a time already in the past).
final class ParseFailure extends ParseOutcome {
  const ParseFailure(this.reason, this.message);
  final ParseFailureReason reason;
  final String message;
}
