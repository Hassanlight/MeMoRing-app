/// Providers for the intelligence layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/features/scheduler/data/rule_based_time_intent_parser.dart';
import 'package:memoring/features/scheduler/domain/parsed_reminder.dart';
import 'package:memoring/features/scheduler/domain/reminder_scheduler.dart';
import 'package:memoring/features/scheduler/domain/time_intent_parser.dart';

final parserProvider = Provider<TimeIntentParser>(
  (ref) => const RuleBasedTimeIntentParser(),
);

final schedulerProvider = Provider<ReminderScheduler>(
  (ref) => const ReminderScheduler(),
);

/// Live parse of the compose text. The UI feeds the current draft in via
/// [composeDraftProvider]; this recomputes the preview deterministically.
final composeDraftProvider = StateProvider<String>((ref) => '');

final livePreviewProvider = Provider<ParseOutcome>((ref) {
  final text = ref.watch(composeDraftProvider);
  final parser = ref.watch(parserProvider);
  return parser.parse(text, now: DateTime.now());
});
