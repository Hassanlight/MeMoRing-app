/// The user's onboarding answers — stored on-device only, never transmitted.
/// Religion is sensitive data: it stays local and only tailors which features show.
library;

import 'package:memoring/features/reminders/domain/reminder.dart';

enum Religion { muslim, other, undisclosed }

final class UserProfile {
  const UserProfile({
    this.name = '',
    this.ageBand = '',
    this.religion = Religion.undisclosed,
    this.prayerReminders = false,
    this.prayerIntensity = ReminderIntensity.medium,
    this.prayerCity = 'Doha',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Migrate the old boolean field (selfie yes/no) to the intensity choice.
    final legacySelfie = json['prayerSelfie'] as bool?;
    final intensityName = json['prayerIntensity'] as String? ??
        ((legacySelfie ?? false) ? 'high' : 'medium');
    return UserProfile(
      name: json['name'] as String? ?? '',
      ageBand: json['ageBand'] as String? ?? '',
      religion:
          Religion.values.byName(json['religion'] as String? ?? 'undisclosed'),
      prayerReminders: json['prayerReminders'] as bool? ?? false,
      prayerIntensity: ReminderIntensity.values.byName(intensityName),
      prayerCity: json['prayerCity'] as String? ?? 'Doha',
    );
  }

  final String name;
  final String ageBand;
  final Religion religion;
  final bool prayerReminders;

  /// How prayer alerts behave: low = one tone, medium = keeps ringing,
  /// high = selfie at a mosque to dismiss.
  final ReminderIntensity prayerIntensity;

  /// City used for prayer-time calculation (see prayer_cities.dart).
  final String prayerCity;

  bool get isMuslim => religion == Religion.muslim;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ageBand': ageBand,
        'religion': religion.name,
        'prayerReminders': prayerReminders,
        'prayerIntensity': prayerIntensity.name,
        'prayerCity': prayerCity,
      };

  UserProfile copyWith({
    String? name,
    String? ageBand,
    Religion? religion,
    bool? prayerReminders,
    ReminderIntensity? prayerIntensity,
    String? prayerCity,
  }) =>
      UserProfile(
        name: name ?? this.name,
        ageBand: ageBand ?? this.ageBand,
        religion: religion ?? this.religion,
        prayerReminders: prayerReminders ?? this.prayerReminders,
        prayerIntensity: prayerIntensity ?? this.prayerIntensity,
        prayerCity: prayerCity ?? this.prayerCity,
      );
}
