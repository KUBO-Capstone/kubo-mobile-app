import 'package:flutter/foundation.dart';

import '../../../shared/data/profile_records.dart';
import '../../../shared/data/synthetic_records.dart';

/// Profile sections shown in the tab row.
enum ProfileSection { listings, reviews, about, saved }

/// Controller that keeps the selected profile section and current view mode.
class ProfilePageController extends ChangeNotifier {
  ProfilePageController({required this.isOwnProfile});

  /// Whether the page is showing the signed-in user's own account.
  final bool isOwnProfile;

  ProfileSection _selectedSection = ProfileSection.listings;

  /// Currently selected section tab.
  ProfileSection get selectedSection => _selectedSection;

  /// Shared profile record used by the page header and about tab.
  SyntheticProfileRecord get profile => syntheticProfileRecord;

  /// Synthetic listings used by the listings tab.
  List<SyntheticListingRecord> get listings => syntheticProfileListings;

  /// Synthetic reviews used by the reviews tab.
  List<SyntheticProfileReviewRecord> get reviews => syntheticProfileReviews;

  /// Synthetic saved listings used by the saved tab.
  List<SyntheticListingRecord> get savedListings =>
      syntheticProfileSavedListings;

  /// Switches to a different profile section.
  void selectSection(ProfileSection section) {
    if (_selectedSection == section) {
      return;
    }

    _selectedSection = section;
    notifyListeners();
  }
}
