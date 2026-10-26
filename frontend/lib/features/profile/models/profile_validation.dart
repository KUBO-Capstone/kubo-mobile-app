class ProfileValidationResult {
  const ProfileValidationResult({
    required this.isValid,
    required this.errors,
  });

  final bool isValid;
  final List<String> errors;
}

class ProfileValidation {
  static ProfileValidationResult validate({
    required String firstName,
    required String lastName,
    required String contactNumber,
    required String bio,
    required String location,
    required String businessName,
    required String businessType,
  }) {
    final errors = <String>[];

    if (firstName.trim().isEmpty) {
      errors.add('First name is required.');
    }
    if (lastName.trim().isEmpty) {
      errors.add('Last name is required.');
    }
    if (contactNumber.trim().isEmpty) {
      errors.add('Contact number is required.');
    }
    if (contactNumber.length > 20) {
      errors.add('Contact number must be 20 characters or fewer.');
    }
    if (bio.length > 500) {
      errors.add('Bio must be 500 characters or fewer.');
    }
    if (location.length > 80) {
      errors.add('Location must be 80 characters or fewer.');
    }
    if (businessName.length > 80) {
      errors.add('Business name must be 80 characters or fewer.');
    }
    if (businessType.length > 40) {
      errors.add('Business type must be 40 characters or fewer.');
    }

    return ProfileValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
