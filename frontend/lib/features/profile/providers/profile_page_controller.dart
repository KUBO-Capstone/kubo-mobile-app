import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../shared/data/profile_records.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/earnings_service.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/profile_service.dart';
import '../../../shared/data/review_service.dart';
import '../../login/services/auth_service.dart';
import '../../saved/providers/saved_listings_controller.dart';

/// Profile sections shown in the tab row. [saved] and [orders] are only
/// meaningful on the signed-in user's own profile.
enum ProfileSection { listings, reviews, about, saved, orders }

/// Which side of the deal the shown reviews come from.
enum ReviewerFilter { all, buyers, sellers }

enum ReviewSort { newest, highest, lowest }

/// The account a visitor profile shows. Built from whatever the caller
/// already has (a listing's seller fields), since there is no user endpoint
/// to fetch a profile by id yet.
class ProfileSubject {
  const ProfileSubject({
    required this.userId,
    required this.displayName,
    this.locationLabel,
    this.photoUrl,
    this.about,
  });

  /// Backend user id, used to fetch this account's listings.
  final int userId;

  /// Name shown in the header, e.g. the listing's `seller_name`.
  final String displayName;

  /// Farm town from the listing, shown on the About tab when known.
  final String? locationLabel;
  final String? photoUrl;
  final String? about;
}

/// Controller that keeps the selected profile section and current view mode.
class ProfilePageController extends ChangeNotifier {
  ProfilePageController({required this.isOwnProfile, this.subject});

  /// Whether the page is showing the signed-in user's own account.
  final bool isOwnProfile;

  /// Account shown when this is a visitor profile; ignored for own profile.
  final ProfileSubject? subject;

  final ListingService _listingService = ListingService();
  final ProfileService _profileService = ProfileService();
  final ReviewService _reviewService = ReviewService();
  final EarningsService _earningsService = EarningsService();
  List<SyntheticListingRecord> _listings = const <SyntheticListingRecord>[];
  Map<String, dynamic>? _loadedProfile;
  UserReviews _userReviews = UserReviews.empty;

  /// False until the first reviews fetch finishes, so the tab can show a
  /// spinner instead of "No reviews yet" while loading.
  bool reviewsLoaded = false;

  ReviewerFilter reviewerFilter = ReviewerFilter.all;

  /// Null shows every star count.
  int? starFilter;
  ReviewSort reviewSort = ReviewSort.newest;

  /// Own profile only; null until loaded or when the request fails.
  EarningsSummary? earnings;

  Map<String, bool> _normalizePrivacy(dynamic value) {
    final defaults = <String, bool>{
      'public_profile': true,
      'show_bio': true,
      'show_contact_number': true,
      'show_location': true,
    };

    if (value == null) {
      return defaults;
    }

    Map<String, dynamic> source;
    if (value is String) {
      try {
        source = Map<String, dynamic>.from(jsonDecode(value));
      } catch (_) {
        return defaults;
      }
    } else if (value is Map) {
      source = Map<String, dynamic>.from(value);
    } else {
      return defaults;
    }

    if (source.isNotEmpty) {
      for (final entry in defaults.entries) {
        if (source[entry.key] is bool) {
          defaults[entry.key] = source[entry.key] as bool;
        }
      }
    }

    return defaults;
  }

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
      final loadedName = '${_loadedProfile?['first_name'] ?? ''} ${_loadedProfile?['last_name'] ?? ''}'.trim();
      final location = (_loadedProfile?['location'] ?? visitor.locationLabel ?? syntheticProfileRecord.locationLabel).toString();
      final businessName = _loadedProfile?['business_name']?.toString() ?? '';
      final businessType = _loadedProfile?['business_type']?.toString() ?? '';
      return SyntheticProfileRecord(
        displayName: loadedName.isEmpty ? visitor.displayName : loadedName,
        username: _loadedProfile?['email']?.toString() ?? 'Kubo grower',
        locationLabel: location,
        about: _loadedProfile?['bio']?.toString().trim().isNotEmpty == true
            ? _loadedProfile!['bio'].toString()
            : visitor.about ?? 'Fresh local produce from a Kubo grower.',
        businessName: businessName,
        businessType: businessType,
        profilePrivacy: _normalizePrivacy(_loadedProfile?['profile_privacy']),
        joinedLabel: syntheticProfileRecord.joinedLabel,
        followingCount: syntheticProfileRecord.followingCount,
        followersCount: syntheticProfileRecord.followersCount,
        listingCount: _listings.length,
        reviewScore: ratingSummary.average ?? 0,
        reviewCount: ratingSummary.count,
        photoUrl: _loadedProfile?['profile_photo_url']?.toString() ?? visitor.photoUrl ?? '',
      );
    }

    final user = AuthService.currentUser;
    if (user == null) {
      return syntheticProfileRecord;
    }

    final firstName = user['first_name']?.toString().trim() ?? '';
    final lastName = user['last_name']?.toString().trim() ?? '';
    final displayName = '$firstName $lastName'.trim();
    final savedBio = (_loadedProfile?['bio'] ?? user['bio'])?.toString().trim() ?? '';
    final savedLocation = (_loadedProfile?['location'] ?? user['location'])?.toString().trim() ?? syntheticProfileRecord.locationLabel;
    final savedBusinessName = (_loadedProfile?['business_name'] ?? user['business_name'])?.toString().trim() ?? '';
    final savedBusinessType = (_loadedProfile?['business_type'] ?? user['business_type'])?.toString().trim() ?? '';
    final addresses = (_loadedProfile?['addresses'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final preferredId = _loadedProfile?['preferred_address_id'];
    final address = addresses.cast<Map<String, dynamic>>().firstWhere(
      (item) => item['address_id'] == preferredId,
      orElse: () => <String, dynamic>{},
    );
    final city = address['city_municipality']?.toString() ?? '';
    final region = address['region']?.toString() ?? '';
    final province = address['province']?.toString() ?? '';
    final addressLocation = city.isEmpty ? '' : '$city, ${region.toUpperCase() == 'NCR' ? region : province}'.trim();
    final createdAtText = _loadedProfile?['created_at']?.toString() ?? '';
    final hasTimeZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(createdAtText);
    final createdAt = DateTime.tryParse(hasTimeZone ? createdAtText : '${createdAtText}Z')?.toLocal();
    return SyntheticProfileRecord(
      displayName: displayName.isEmpty ? syntheticProfileRecord.displayName : displayName,
      username: user['email']?.toString() ?? syntheticProfileRecord.username,
      locationLabel: addressLocation.isEmpty ? savedLocation : addressLocation,
      about: savedBio.isEmpty ? syntheticProfileRecord.about : savedBio,
      businessName: savedBusinessName,
      businessType: savedBusinessType,
      profilePrivacy: _normalizePrivacy(_loadedProfile?['profile_privacy'] ?? user['profile_privacy']),
      joinedLabel: createdAt == null
          ? ''
          : '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}/${createdAt.year}',
      followingCount: syntheticProfileRecord.followingCount,
      followersCount: syntheticProfileRecord.followersCount,
      listingCount: _listings.length,
      reviewScore: ratingSummary.average ?? 0,
      reviewCount: ratingSummary.count,
      photoUrl: _loadedProfile?['profile_photo_url']?.toString() ?? user['profile_photo_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic>? get loadedProfile => _loadedProfile;

  Future<void> loadProfile() async {
    final userId = _subjectUserId;
    if (userId == null) return;
    try {
      _loadedProfile = await _profileService.fetchProfile(userId);
      if (isOwnProfile) AuthService.updateCurrentUser(_loadedProfile!);
      notifyListeners();
    } catch (_) {
      // The cached login profile remains visible while the network is unavailable.
    }
  }

  Future<void> setProfile(Map<String, dynamic> profile) async {
    _loadedProfile = profile;
    if (isOwnProfile) AuthService.updateCurrentUser(profile);
    notifyListeners();
  }

  /// Synthetic listings used by the listings tab.
  List<SyntheticListingRecord> get listings => _listings;

  RatingSummary get ratingSummary => _userReviews.summary;

  /// Whether this account has any review at all, before filters.
  bool get hasAnyReviews => _userReviews.reviews.isNotEmpty;

  /// The Reviews tab list after the side / star filters and the sort.
  List<ReviewRecord> get reviews {
    final filtered = _userReviews.reviews.where((review) {
      if (reviewerFilter == ReviewerFilter.buyers && review.reviewerRole != ReviewerRole.buyer) return false;
      if (reviewerFilter == ReviewerFilter.sellers && review.reviewerRole != ReviewerRole.seller) return false;
      return starFilter == null || review.rating == starFilter;
    }).toList();
    switch (reviewSort) {
      case ReviewSort.newest:
        break; // The server already returns newest first.
      case ReviewSort.highest:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
      case ReviewSort.lowest:
        filtered.sort((a, b) => a.rating.compareTo(b.rating));
    }
    return filtered;
  }

  Future<void> loadReviews() async {
    final userId = _subjectUserId;
    if (userId == null) {
      reviewsLoaded = true;
      notifyListeners();
      return;
    }
    try {
      _userReviews = await _reviewService.fetchUserReviews(userId);
    } catch (_) {
      // Keeps whatever was shown before; the tab still renders.
    }
    reviewsLoaded = true;
    notifyListeners();
  }

  void setReviewFilters({ReviewerFilter? reviewer, int? Function()? stars, ReviewSort? sort}) {
    if (reviewer != null) reviewerFilter = reviewer;
    if (stars != null) starFilter = stars();
    if (sort != null) reviewSort = sort;
    notifyListeners();
  }

  /// Lifetime earnings for the banner on the owner's profile.
  Future<void> loadEarnings() async {
    final userId = AuthService.currentUserId;
    if (!isOwnProfile || userId == null) return;
    try {
      earnings = await _earningsService.fetchEarnings(userId);
      notifyListeners();
    } catch (_) {
      // The banner just stays hidden while the server is unreachable.
    }
  }

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
    _profileService.dispose();
    _reviewService.dispose();
    _earningsService.dispose();
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
