/// Providers for the user profile.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoring/features/onboarding/data/profile_repository.dart';
import 'package:memoring/features/onboarding/domain/user_profile.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

/// The current profile (null until onboarding is completed).
final profileProvider = FutureProvider<UserProfile?>(
  (ref) => ref.read(profileRepositoryProvider).load(),
);
