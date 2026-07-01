/// The core reminder entity (+ JSON serialization for on-device persistence).
library;

import 'package:memoring/features/reminders/domain/recurrence.dart';

/// Short-term (< 30 days) vs long-term (>= 30 days) queue.
enum ReminderType { short, long }

/// How insistent the alert is.
/// - [low]: pops up with a single tone, once.
/// - [medium]: pops up and keeps ringing until dismissed.
/// - [high]: keeps ringing until the user takes a selfie to confirm.
enum ReminderIntensity { low, medium, high }

/// An immutable reminder. [fireAt] is the next occurrence as local wall-clock
/// time; [text] is already cleaned of its time phrase. [imagePath] is an
/// optional on-device photo shown in the alert and notification.
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
    this.imagePath,
    this.intensity = ReminderIntensity.low,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    DateTime? at(String key) {
      final v = json[key];
      return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    }

    return Reminder(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: at('createdAt')!,
      fireAt: at('fireAt')!,
      type: ReminderType.values.byName(json['type'] as String),
      recurrence: Recurrence(
        RecurrenceType.values.byName(json['recurrenceType'] as String),
        weekday: json['weekday'] as int?,
      ),
      isActive: json['isActive'] as bool? ?? true,
      snoozedUntil: at('snoozedUntil'),
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      completedAt: at('completedAt'),
      imagePath: json['imagePath'] as String?,
      intensity: ReminderIntensity.values
          .byName(json['intensity'] as String? ?? 'low'),
    );
  }

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
  final String? imagePath;
  final ReminderIntensity intensity;

  bool get isCompleted => completedAt != null;

  /// The moment this reminder will actually alert (snooze overrides fireAt).
  DateTime get effectiveFireAt => snoozedUntil ?? fireAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'fireAt': fireAt.millisecondsSinceEpoch,
        'type': type.name,
        'recurrenceType': recurrence.type.name,
        'weekday': recurrence.weekday,
        'isActive': isActive,
        'snoozedUntil': snoozedUntil?.millisecondsSinceEpoch,
        'soundEnabled': soundEnabled,
        'completedAt': completedAt?.millisecondsSinceEpoch,
        'imagePath': imagePath,
        'intensity': intensity.name,
      };

  Reminder copyWith({
    String? text,
    DateTime? fireAt,
    ReminderType? type,
    Recurrence? recurrence,
    bool? isActive,
    bool? soundEnabled,
    DateTime? Function()? snoozedUntil,
    DateTime? Function()? completedAt,
    String? Function()? imagePath,
    ReminderIntensity? intensity,
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
      imagePath: imagePath != null ? imagePath() : this.imagePath,
      intensity: intensity ?? this.intensity,
    );
  }
}
