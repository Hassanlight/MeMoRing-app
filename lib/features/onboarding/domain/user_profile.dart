/// The user's onboarding answers — stored on-device only, never transmitted.
/// Religion is sensitive data: it stays local and only tailors which features show.
library;

enum Religion { muslim, other, undisclosed }

final class UserProfile {
  const UserProfile({
    this.name = '',
    this.ageBand = '',
    this.religion = Religion.undisclosed,
    this.prayerReminders = false,
    this.prayerSelfie = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        ageBand: json['ageBand'] as String? ?? '',
        religion: Religion.values
            .byName(json['religion'] as String? ?? 'undisclosed'),
        prayerReminders: json['prayerReminders'] as bool? ?? false,
        prayerSelfie: json['prayerSelfie'] as bool? ?? false,
      );

  final String name;
  final String ageBand;
  final Religion religion;
  final bool prayerReminders;

  /// How prayer alerts are confirmed: true = selfie at a mosque, false = just ring.
  final bool prayerSelfie;

  bool get isMuslim => religion == Religion.muslim;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ageBand': ageBand,
        'religion': religion.name,
        'prayerReminders': prayerReminders,
        'prayerSelfie': prayerSelfie,
      };

  UserProfile copyWith({
    String? name,
    String? ageBand,
    Religion? religion,
    bool? prayerReminders,
    bool? prayerSelfie,
  }) =>
      UserProfile(
        name: name ?? this.name,
        ageBand: ageBand ?? this.ageBand,
        religion: religion ?? this.religion,
        prayerReminders: prayerReminders ?? this.prayerReminders,
        prayerSelfie: prayerSelfie ?? this.prayerSelfie,
      );
}
