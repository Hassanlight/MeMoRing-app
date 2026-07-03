/// Derives usage insights from the user's reminders. Pure + testable.
library;

import 'package:memoring/features/reminders/domain/reminder.dart';

/// A snapshot of reminder-usage insights.
final class AnalyticsSummary {
  const AnalyticsSummary({
    required this.total,
    required this.completed,
    required this.active,
    required this.recurring,
    required this.withPhoto,
    required this.byIntensity,
    required this.topTopics,
    required this.prayerLog,
  });

  final int total;
  final int completed;
  final int active;
  final int recurring;
  final int withPhoto;
  final Map<ReminderIntensity, int> byIntensity;

  /// Most frequent subject words — "what you remind yourself about most".
  final List<MapEntry<String, int>> topTopics;

  /// Completed prayers (most recent first), each with its confirmation photo.
  final List<Reminder> prayerLog;

  int get completionPercent => total == 0 ? 0 : ((completed / total) * 100).round();

  bool get isEmpty => total == 0;
}

const _stopwords = {
  'the', 'a', 'an', 'to', 'my', 'in', 'on', 'at', 'of', 'for', 'and', 'me',
  'i', 'is', 'it', 'with', 'by', 'this', 'that', 'up', 'get', 'go', 'do',
  'am', 'pm', 'call', 'off', 'out', 'be', 'so', 'we',
};

AnalyticsSummary computeAnalytics(List<Reminder> reminders) {
  final counts = <String, int>{};
  var completed = 0;
  var active = 0;
  var recurring = 0;
  var withPhoto = 0;
  final byIntensity = <ReminderIntensity, int>{
    for (final i in ReminderIntensity.values) i: 0,
  };

  for (final r in reminders) {
    if (r.isCompleted) {
      completed++;
    } else {
      active++;
    }
    if (r.recurrence.isRecurring) recurring++;
    if (r.imagePath != null) withPhoto++;
    byIntensity[r.intensity] = (byIntensity[r.intensity] ?? 0) + 1;

    for (final raw in r.text.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (raw.length < 3 || _stopwords.contains(raw)) continue;
      counts[raw] = (counts[raw] ?? 0) + 1;
    }
  }

  final topTopics = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final prayerLog = reminders
      .where((r) => r.id.startsWith('prayer_') && r.isCompleted)
      .toList()
    ..sort((a, b) =>
        (b.completedAt ?? b.fireAt).compareTo(a.completedAt ?? a.fireAt));

  return AnalyticsSummary(
    total: reminders.length,
    completed: completed,
    active: active,
    recurring: recurring,
    withPhoto: withPhoto,
    byIntensity: byIntensity,
    topTopics: topTopics.take(8).toList(),
    prayerLog: prayerLog,
  );
}
