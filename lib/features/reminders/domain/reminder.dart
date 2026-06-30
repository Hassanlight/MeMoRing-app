/// The core reminder entity.
library;

import 'package:memoring/features/reminders/domain/recurrence.dart';

/// Short-term (< 30 days) vs long-term (>= 30 days) queue.
enum ReminderType { short, long }

/// An immutable reminder. [fireAt] is the next occurrence as local wall-clock
/// time; persistence converts to UTC. [text] is already cleaned of its time phrase.
final class Reminder {
  const Reminder({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.fireAt,
    required this.type,
    required this.recurrence,
    this.isActive = true,
    this.snoozedUntil,
    this.soundEnabled = true,
    this.completedAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime fireAt;
  final ReminderType type;
  final Recurrence recurrence;
  final bool isActive;
  final DateTime? snoozedUntil;
  final bool soundEnabled;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  /// The moment this reminder will actually alert (snooze overrides fireAt).
  DateTime get effectiveFireAt => snoozedUntil ?? fireAt;

  Reminder copyWith({
    String? text,
    DateTime? fireAt,
    ReminderType? type,
    Recurrence? recurrence,
    bool? isActive,
    bool? soundEnabled,
    DateTime? Function()? snoozedUntil,
    DateTime? Function()? completedAt,
  }) {
    return Reminder(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      fireAt: fireAt ?? this.fireAt,
      type: type ?? this.type,
      recurrence: recurrence ?? this.recurrence,
      isActive: isActive ?? this.isActive,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      snoozedUntil: snoozedUntil != null ? snoozedUntil() : this.snoozedUntil,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
    );
  }
}
