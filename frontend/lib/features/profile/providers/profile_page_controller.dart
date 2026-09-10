import 'package:flutter/foundation.dart';

import '../../../shared/data/profile_records.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/listing_service.dart';
import '../../login/services/auth_service.dart';

/// Profile sections shown in the tab row.
enum ProfileSection { listings, reviews, about, saved }

/// Controller that keeps the selected profile section and current view mode.
class ProfilePageController extends ChangeNotifier {
  ProfilePageController({required this.isOwnProfile});

  /// Whether the page is showing the signed-in user's own account.
  final bool isOwnProfile;
  final ListingService _listingService = ListingService();
  List<SyntheticListingRecord> _listings = const <SyntheticListingRecord>[];

  ProfileSection _selectedSection = ProfileSection.listings;

  /// Currently selected section tab.
  ProfileSection get selectedSection => _selectedSection;

  /// Shared profile record used by the page header and about tab.
  SyntheticProfileRecord get profile {
    final user = AuthService.currentUser;
    if (user == null) {
      return syntheticProfileRecord;
    }

    final firstName = user['first_name']?.toString().trim() ?? '';
    final lastName = user['last_name']?.toString().trim() ?? '';
    final displayName = '$firstName $lastName'.trim();
    return SyntheticProfileRecord(
      displayName: displayName.isEmpty ? syntheticProfileRecord.displayName : displayName,
      username: user['email']?.toString() ?? syntheticProfileRecord.username,
      locationLabel: syntheticProfileRecord.locationLabel,
      about: syntheticProfileRecord.about,
      joinedLabel: syntheticProfileRecord.joinedLabel,
      followingCount: syntheticProfileRecord.followingCount,
      followersCount: syntheticProfileRecord.followersCount,
      listingCount: _listings.length,
      reviewScore: syntheticProfileRecord.reviewScore,
      reviewCount: syntheticProfileRecord.reviewCount,
    );
  }

  /// Synthetic listings used by the listings tab.
  List<SyntheticListingRecord> get listings => _listings;

  /// Synthetic reviews used by the reviews tab.
  List<SyntheticProfileReviewRecord> get reviews => syntheticProfileReviews;

  /// Synthetic saved listings used by the saved tab.
  List<SyntheticListingRecord> get savedListings =>
      syntheticProfileSavedListings;

  Future<void> loadListings() async {
    try {
      final userId = int.tryParse(AuthService.currentUser?['user_id']?.toString() ?? '');
      if (userId == null) {
        _listings = const <SyntheticListingRecord>[];
        notifyListeners();
        return;
      }
      _listings = await _listingService.fetchListings(sellerId: userId);
      notifyListeners();
    } catch (_) {
      _listings = const <SyntheticListingRecord>[];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _listingService.dispose();
    super.dispose();
  }

  /// Switches to a different profile section.
  void selectSection(ProfileSection section) {
    if (_selectedSection == section) {
      return;
    }

    _selectedSection = section;
    notifyListeners();
  }
}
