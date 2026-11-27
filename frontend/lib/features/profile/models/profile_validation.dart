/// Names of the fields [ProfileValidationResult.fieldErrors] can point at.
enum ProfileField { firstName, lastName, contactNumber, bio, location, businessName, businessType }

class ProfileValidationResult {
  const ProfileValidationResult({
    required this.isValid,
    required this.errors,
    this.fieldErrors = const <ProfileField, String>{},
  });

  final bool isValid;
  final List<String> errors;

  /// The first problem with each field, for showing under that field.
  final Map<ProfileField, String> fieldErrors;
}

class ProfileValidation {
  /// Characters a phone number may be typed with.
  static final contactNumberCharacters = RegExp(r'[0-9+\-\s()]');

  static ProfileValidationResult validate({
    required String firstName,
    required String lastName,
    required String contactNumber,
    required String bio,
    required String location,
    required String businessName,
    required String businessType,
  }) {
    final fieldErrors = <ProfileField, String>{};
    final errors = <String>[];
    void add(ProfileField field, String message) {
      errors.add(message);
      fieldErrors.putIfAbsent(field, () => message);
    }

    if (firstName.trim().isEmpty) {
      add(ProfileField.firstName, 'First name is required.');
    }
    if (lastName.trim().isEmpty) {
      add(ProfileField.lastName, 'Last name is required.');
    }
    final digits = contactNumber.replaceAll(RegExp(r'\D'), '').length;
    if (contactNumber.trim().isEmpty) {
      add(ProfileField.contactNumber, 'Contact number is required.');
    } else if (contactNumber.split('').any((c) => !contactNumberCharacters.hasMatch(c))) {
      add(ProfileField.contactNumber, 'Use numbers only, e.g. 0917 123 4567.');
    } else if (digits < 7) {
      add(ProfileField.contactNumber, 'This number looks too short.');
    }
    if (contactNumber.length > 15) {
      add(ProfileField.contactNumber, 'Contact number must be 15 characters or fewer.');
    }
    if (bio.length > 500) {
      add(ProfileField.bio, 'Bio must be 500 characters or fewer.');
    }
    if (location.length > 80) {
      add(ProfileField.location, 'Location must be 80 characters or fewer.');
    }
    if (businessName.length > 80) {
      add(ProfileField.businessName, 'Business name must be 80 characters or fewer.');
    }
    if (businessType.length > 40) {
      add(ProfileField.businessType, 'Business type must be 40 characters or fewer.');
    }

    return ProfileValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }
}
