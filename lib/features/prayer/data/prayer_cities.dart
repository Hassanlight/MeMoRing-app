/// Worldwide city list for prayer-time calculation — offline, no GPS needed.
/// Each city carries its coordinates and the calculation method used in that
/// region (matters: Umm al-Qura vs Karachi vs ISNA differ by many minutes).
library;

final class PrayerCity {
  const PrayerCity(this.name, this.country, this.lat, this.lng, this.method);
  final String name;
  final String country;
  final double lat;
  final double lng;
  final String method;

  String get label => '$name, $country';
}

const List<PrayerCity> kPrayerCities = [
  // Gulf
  PrayerCity('Doha', 'Qatar', 25.2854, 51.5310, 'qatar'),
  PrayerCity('Dubai', 'UAE', 25.2048, 55.2708, 'dubai'),
  PrayerCity('Abu Dhabi', 'UAE', 24.4539, 54.3773, 'dubai'),
  PrayerCity('Riyadh', 'Saudi Arabia', 24.7136, 46.6753, 'umm_al_qura'),
  PrayerCity('Jeddah', 'Saudi Arabia', 21.4858, 39.1925, 'umm_al_qura'),
  PrayerCity('Mecca', 'Saudi Arabia', 21.3891, 39.8579, 'umm_al_qura'),
  PrayerCity('Medina', 'Saudi Arabia', 24.5247, 39.5692, 'umm_al_qura'),
  PrayerCity('Kuwait City', 'Kuwait', 29.3759, 47.9774, 'kuwait'),
  PrayerCity('Manama', 'Bahrain', 26.2285, 50.5860, 'umm_al_qura'),
  PrayerCity('Muscat', 'Oman', 23.5880, 58.3829, 'umm_al_qura'),
  // South Asia
  PrayerCity('Karachi', 'Pakistan', 24.8607, 67.0011, 'karachi'),
  PrayerCity('Lahore', 'Pakistan', 31.5204, 74.3587, 'karachi'),
  PrayerCity('Islamabad', 'Pakistan', 33.6844, 73.0479, 'karachi'),
  PrayerCity('Peshawar', 'Pakistan', 34.0151, 71.5249, 'karachi'),
  PrayerCity('Delhi', 'India', 28.7041, 77.1025, 'karachi'),
  PrayerCity('Mumbai', 'India', 19.0760, 72.8777, 'karachi'),
  PrayerCity('Hyderabad', 'India', 17.3850, 78.4867, 'karachi'),
  PrayerCity('Dhaka', 'Bangladesh', 23.8103, 90.4125, 'karachi'),
  PrayerCity('Kabul', 'Afghanistan', 34.5553, 69.2075, 'karachi'),
  // Southeast Asia
  PrayerCity('Jakarta', 'Indonesia', -6.2088, 106.8456, 'singapore'),
  PrayerCity('Kuala Lumpur', 'Malaysia', 3.1390, 101.6869, 'singapore'),
  PrayerCity('Singapore', 'Singapore', 1.3521, 103.8198, 'singapore'),
  // Middle East & North Africa
  PrayerCity('Cairo', 'Egypt', 30.0444, 31.2357, 'egyptian'),
  PrayerCity('Alexandria', 'Egypt', 31.2001, 29.9187, 'egyptian'),
  PrayerCity('Amman', 'Jordan', 31.9454, 35.9284, 'muslim_world_league'),
  PrayerCity('Beirut', 'Lebanon', 33.8938, 35.5018, 'muslim_world_league'),
  PrayerCity('Baghdad', 'Iraq', 33.3152, 44.3661, 'muslim_world_league'),
  PrayerCity('Damascus', 'Syria', 33.5138, 36.2765, 'muslim_world_league'),
  PrayerCity('Istanbul', 'Türkiye', 41.0082, 28.9784, 'turkey'),
  PrayerCity('Ankara', 'Türkiye', 39.9334, 32.8597, 'turkey'),
  PrayerCity('Tehran', 'Iran', 35.6892, 51.3890, 'tehran'),
  PrayerCity('Casablanca', 'Morocco', 33.5731, -7.5898, 'muslim_world_league'),
  PrayerCity('Algiers', 'Algeria', 36.7538, 3.0588, 'muslim_world_league'),
  PrayerCity('Tunis', 'Tunisia', 36.8065, 10.1815, 'muslim_world_league'),
  PrayerCity('Tripoli', 'Libya', 32.8872, 13.1913, 'muslim_world_league'),
  PrayerCity('Khartoum', 'Sudan', 15.5007, 32.5599, 'muslim_world_league'),
  // Sub-Saharan Africa
  PrayerCity('Lagos', 'Nigeria', 6.5244, 3.3792, 'muslim_world_league'),
  PrayerCity('Nairobi', 'Kenya', -1.2921, 36.8219, 'muslim_world_league'),
  PrayerCity('Mogadishu', 'Somalia', 2.0469, 45.3182, 'muslim_world_league'),
  // Europe
  PrayerCity('London', 'UK', 51.5074, -0.1278, 'moon_sighting_committee'),
  PrayerCity('Paris', 'France', 48.8566, 2.3522, 'muslim_world_league'),
  PrayerCity('Berlin', 'Germany', 52.5200, 13.4050, 'muslim_world_league'),
  PrayerCity('Amsterdam', 'Netherlands', 52.3676, 4.9041, 'muslim_world_league'),
  PrayerCity('Stockholm', 'Sweden', 59.3293, 18.0686, 'muslim_world_league'),
  // Americas
  PrayerCity('New York', 'USA', 40.7128, -74.0060, 'north_america'),
  PrayerCity('Chicago', 'USA', 41.8781, -87.6298, 'north_america'),
  PrayerCity('Houston', 'USA', 29.7604, -95.3698, 'north_america'),
  PrayerCity('Los Angeles', 'USA', 34.0522, -118.2437, 'north_america'),
  PrayerCity('Toronto', 'Canada', 43.6532, -79.3832, 'north_america'),
  // Central Asia / other
  PrayerCity('Tashkent', 'Uzbekistan', 41.2995, 69.2401, 'muslim_world_league'),
  PrayerCity('Baku', 'Azerbaijan', 40.4093, 49.8671, 'muslim_world_league'),
  PrayerCity('Sydney', 'Australia', -33.8688, 151.2093, 'muslim_world_league'),
];

/// Finds a city by exact name; falls back to Doha (the previous default) so
/// existing users keep working times.
PrayerCity cityByName(String? name) => kPrayerCities.firstWhere(
      (c) => c.name == name,
      orElse: () => kPrayerCities.first,
    );
