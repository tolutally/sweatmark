import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the user profile document stored under
/// `users/{uid}/profile/data` in Firestore.
class ProfileModel {
  ProfileModel({
    required this.displayName,
    required this.handle,
    required this.createdAt,
    required this.totalWorkouts,
    required this.totalPersonalRecords,
    this.location,
    this.bio,
    this.instagramHandle,
    this.avatarUrl,
  });

  final String displayName;
  final String handle;
  final DateTime? createdAt;
  final int totalWorkouts;
  final int totalPersonalRecords;
  final String? location;
  final String? bio;
  final String? instagramHandle;
  final String? avatarUrl;

  static const String documentId = 'data';

  ProfileModel copyWith({
    String? displayName,
    String? handle,
    DateTime? createdAt,
    int? totalWorkouts,
    int? totalPersonalRecords,
    String? location,
    String? bio,
    String? instagramHandle,
    String? avatarUrl,
  }) {
    return ProfileModel(
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      createdAt: createdAt ?? this.createdAt,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      totalPersonalRecords: totalPersonalRecords ?? this.totalPersonalRecords,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'location': location,
      'instagram': instagramHandle,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'stats': {
        'totalWorkouts': totalWorkouts,
        'totalPRs': totalPersonalRecords,
      },
    }..removeWhere((key, value) => value == null);
  }

  static ProfileModel fromFirestore(Map<String, dynamic> data) {
    final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? const {});
    final createdAtValue = data['createdAt'];

    DateTime? createdAt;
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    }

    return ProfileModel(
      displayName: (data['username'] as String?)?.trim().isNotEmpty == true
          ? data['username'] as String
          : 'Flex User',
      handle: (data['handle'] as String?)?.trim().isNotEmpty == true
          ? data['handle'] as String
          : '@sweatmark_user',
      createdAt: createdAt,
      avatarUrl: data['avatarUrl'] as String?,
      bio: data['bio'] as String?,
      location: data['location'] as String?,
      instagramHandle: data['instagram'] as String?,
      totalWorkouts: (stats['totalWorkouts'] as num?)?.toInt() ?? 0,
      totalPersonalRecords: (stats['totalPRs'] as num?)?.toInt() ?? 0,
    );
  }

  static ProfileModel defaults() {
    return ProfileModel(
      displayName: 'Flex User',
      handle: '@sweatmark_user',
      createdAt: DateTime.now(),
      totalWorkouts: 0,
      totalPersonalRecords: 0,
    );
  }
}
