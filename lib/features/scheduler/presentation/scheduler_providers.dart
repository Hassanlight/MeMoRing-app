/// Providers for the intelligence layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/features/scheduler/data/rule_based_time_intent_parser.dart';
import 'package:memoring/features/scheduler/domain/reminder_scheduler.dart';
import 'package:memoring/features/scheduler/domain/time_intent_parser.dart';

final parserProvider = Provider<TimeIntentParser>(
  (ref) => const RuleBasedTimeIntentParser(),
);

final schedulerProvider = Provider<ReminderScheduler>(
  (ref) => const ReminderScheduler(),
);
