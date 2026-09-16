import 'package:flutter/foundation.dart';

import '../../../shared/data/profile_records.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/listing_service.dart';
import '../../login/services/auth_service.dart';
import '../../saved/providers/saved_listings_controller.dart';

/// Profile sections shown in the tab row.
enum ProfileSection { listings, reviews, about, saved }

/// The account a visitor profile shows. Built from whatever the caller
/// already has (a listing's seller fields), since there is no user endpoint
/// to fetch a profile by id yet.
class ProfileSubject {
  const ProfileSubject({
    required this.userId,
    required this.displayName,
    this.locationLabel,
  });

  /// Backend user id, used to fetch this account's listings.
  final int userId;

  /// Name shown in the header, e.g. the listing's `seller_name`.
  final String displayName;

  /// Farm town from the listing, shown on the About tab when known.
  final String? locationLabel;
}

/// Controller that keeps the selected profile section and current view mode.
class ProfilePageController extends ChangeNotifier {
  ProfilePageController({required this.isOwnProfile, this.subject});

  /// Whether the page is showing the signed-in user's own account.
  final bool isOwnProfile;

  /// Account shown when this is a visitor profile; ignored for own profile.
  final ProfileSubject? subject;

  final ListingService _listingService = ListingService();
  List<SyntheticListingRecord> _listings = const <SyntheticListingRecord>[];

  /// Whose listings the Listings tab shows.
  int? get _subjectUserId =>
      isOwnProfile ? AuthService.currentUserId : subject?.userId;

  ProfileSection _selectedSection = ProfileSection.listings;

  /// Currently selected section tab.
  ProfileSection get selectedSection => _selectedSection;

  /// Shared profile record used by the page header and about tab.
  SyntheticProfileRecord get profile {
    final visitor = subject;
    if (!isOwnProfile && visitor != null) {
      // Only the name, town and listing count are real; the rest stays
      // synthetic until reviews and follows exist on the backend.
      return SyntheticProfileRecord(
        displayName: visitor.displayName,
        username: 'Kubo grower',
        locationLabel:
            visitor.locationLabel ?? syntheticProfileRecord.locationLabel,
        about: 'Fresh local produce from a Kubo grower.',
        joinedLabel: syntheticProfileRecord.joinedLabel,
        followingCount: syntheticProfileRecord.followingCount,
        followersCount: syntheticProfileRecord.followersCount,
        listingCount: _listings.length,
        reviewScore: syntheticProfileRecord.reviewScore,
        reviewCount: syntheticProfileRecord.reviewCount,
      );
    }

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

  /// The signed-in user's saved listings (own profile only), from the
  /// app-wide store so the tab and the hearts elsewhere agree.
  List<SyntheticListingRecord> get savedListings =>
      SavedListingsController.instance.listings;

  Future<void> loadListings() async {
    try {
      final userId = _subjectUserId;
      if (userId == null) {
        _listings = const <SyntheticListingRecord>[];
        notifyListeners();
        return;
      }
      // Only the owner sees their sold-out listings; visitors get the same
      // list the explore tab shows.
      _listings = await _listingService.fetchListings(
        sellerId: userId,
        includeUnavailable: isOwnProfile,
      );
      notifyListeners();
    } catch (_) {
      _listings = const <SyntheticListingRecord>[];
      notifyListeners();
    }
  }

  /// Applies a manage-sheet outcome locally so the grid updates at once;
  /// the caller still reloads to pick up server-side ordering.
  void applyOutcome(String listingId, {SyntheticListingRecord? updated}) {
    _listings = <SyntheticListingRecord>[
      for (final listing in _listings)
        if (listing.id != listingId)
          listing
        else if (updated != null)
          updated,
    ];
    notifyListeners();
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
