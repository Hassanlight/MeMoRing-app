/// Contract for the intelligence layer. v1 is rule-based; v2 may swap an LLM
/// behind this same interface with no change to callers.
library;

import 'package:memoring/features/scheduler/domain/parsed_reminder.dart';

/// Hard cap on input length — defensive against pathological/abusive input.
const int kMaxReminderInputLength = 500;

/// Turns free text into a [ParseOutcome]. Pure and deterministic: [now] is
/// injected so the same input always yields the same result in tests.
abstract interface class TimeIntentParser {
  ParseOutcome parse(String input, {required DateTime now});
}
