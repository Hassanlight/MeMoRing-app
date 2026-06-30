/// How often a reminder repeats.
library;

/// The kind of repetition.
enum RecurrenceType { none, daily, weekly, monthly, yearly }

/// A recurrence rule. For [RecurrenceType.weekly] the [weekday] (1=Mon..7=Sun,
/// matching [DateTime.weekday]) pins which day. Monthly/yearly repeat on the
/// day-of-month (and month) of the reminder's fire time.
final class Recurrence {
  const Recurrence(this.type, {this.weekday});

  /// No repetition.
  const Recurrence.none() : this(RecurrenceType.none);

  final RecurrenceType type;
  final int? weekday;

  bool get isRecurring => type != RecurrenceType.none;

  /// Recurring reminders that fire frequently are short-term; rare ones long-term.
  bool get isLongTermCadence =>
      type == RecurrenceType.monthly || type == RecurrenceType.yearly;

  @override
  bool operator ==(Object other) =>
      other is Recurrence && other.type == type && other.weekday == weekday;

  @override
  int get hashCode => Object.hash(type, weekday);

  @override
  String toString() =>
      'Recurrence(${type.name}${weekday != null ? ', wd=$weekday' : ''})';
}
