import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweatmark/models/profile_model.dart';

void main() {
  group('ProfileModel', () {
    test('fromFirestore maps fields and falls back to defaults', () {
      final data = {
        'username': 'Test User',
        'handle': '@tester',
        'bio': 'Let\'s lift!',
        'location': 'Toronto',
        'instagram': 'test_fit',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(0),
        'stats': {
          'totalWorkouts': 12,
          'totalPRs': 4,
        },
      };

      final model = ProfileModel.fromFirestore(data);

      expect(model.displayName, 'Test User');
      expect(model.handle, '@tester');
      expect(model.bio, 'Let\'s lift!');
      expect(model.location, 'Toronto');
      expect(model.instagramHandle, 'test_fit');
      expect(model.totalWorkouts, 12);
      expect(model.totalPersonalRecords, 4);
    });

    test('toFirestore omits null values and keeps stats', () {
      final model = ProfileModel(
        displayName: 'Flex User',
        handle: '@flex',
        createdAt: DateTime.utc(2024, 1, 1),
        totalWorkouts: 3,
        totalPersonalRecords: 1,
      );

      final map = model.toFirestore();

      expect(map['username'], 'Flex User');
      expect(map['handle'], '@flex');
      expect(map['bio'], isNull);
      expect(map['location'], isNull);
      expect(map['instagram'], isNull);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['stats'], {
        'totalWorkouts': 3,
        'totalPRs': 1,
      });
    });
  });
}
