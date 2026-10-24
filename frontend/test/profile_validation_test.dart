import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/models/profile_validation.dart';

void main() {
  group('ProfileValidation', () {
    test('accepts valid profile data', () {
      final result = ProfileValidation.validate(
        firstName: 'Maria',
        lastName: 'Dela Cruz',
        contactNumber: '09171234567',
        bio: 'Fresh produce from our farm.',
        location: 'Caybiga',
        businessName: 'Green Valley Farm',
        businessType: 'Vegetable supplier',
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects overly long values and empty required fields', () {
      final result = ProfileValidation.validate(
        firstName: '',
        lastName: 'Dela Cruz',
        contactNumber: '09171234567',
        bio: 'A' * 501,
        location: 'A' * 81,
        businessName: 'B' * 81,
        businessType: 'C' * 41,
      );

      expect(result.isValid, isFalse);
      expect(result.errors, contains('First name is required.'));
      expect(result.errors, contains('Bio must be 500 characters or fewer.'));
      expect(result.errors, contains('Location must be 80 characters or fewer.'));
      expect(result.errors, contains('Business name must be 80 characters or fewer.'));
      expect(result.errors, contains('Business type must be 40 characters or fewer.'));
    });
  });
}
