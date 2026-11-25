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

  /// The profile shown in the header and the About tab. Every value comes
  /// from the account: what the server returned for it, or, until that
  /// arrives, what the caller already knew (the signed-in user's row, or the
  /// seller fields of the listing a visitor came from). Anything the account
  /// has not filled in is left empty for the page to handle, never padded
  /// with sample text.
  SyntheticProfileRecord get profile {
    final loaded = _loadedProfile;
    final visitor = subject;
    final user = isOwnProfile ? AuthService.currentUser : null;

    String field(String key) => (loaded?[key] ?? user?[key])?.toString().trim() ?? '';
    // Like field(): the signed-in user's saved row stands in until (or in
    // case) the profile loads, so their own counts survive a failed fetch.
    int count(String key) {
      final value = loaded?[key] ?? user?[key];
      return value is num ? value.toInt() : 0;
    }

    final name = '${field('first_name')} ${field('last_name')}'.trim();
    final displayName = name.isNotEmpty
        ? name
        : isOwnProfile
            ? (user == null ? 'Guest' : 'Kubo member')
            : (visitor?.displayName ?? 'Kubo member');

    // The town of the preferred address, when the profile carries addresses
    // (a visited profile that hides its location has had them taken out, see
    // loadProfile); otherwise the location typed on the profile, or the one
    // the listing showed.
    final addresses = (loaded?['addresses'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final preferredId = loaded?['preferred_address_id'];
    final address = addresses.cast<Map<String, dynamic>>().firstWhere(
      (item) => item['address_id'] == preferredId,
      orElse: () => <String, dynamic>{},
    );
    final city = address['city_municipality']?.toString() ?? '';
    final region = address['region']?.toString() ?? '';
    final province = address['province']?.toString() ?? '';
    final addressLocation = city.isEmpty ? '' : '$city, ${region.toUpperCase() == 'NCR' ? region : province}'.trim();
    final typedLocation = field('location');
    final locationLabel = addressLocation.isNotEmpty
        ? addressLocation
        : typedLocation.isNotEmpty
            ? typedLocation
            : (isOwnProfile ? '' : visitor?.locationLabel?.trim() ?? '');

    final bio = field('bio');
    final photo = field('profile_photo_url');
    return SyntheticProfileRecord(
      displayName: displayName,
      username: field('email'),
      locationLabel: locationLabel,
      about: bio.isNotEmpty ? bio : (isOwnProfile ? '' : visitor?.about?.trim() ?? ''),
      businessName: field('business_name'),
      businessType: field('business_type'),
      profilePrivacy: _normalizePrivacy(loaded?['profile_privacy'] ?? user?['profile_privacy']),
      joinedLabel: _joinedLabel(field('created_at')),
      followingCount: count('following_count'),
      followersCount: count('followers_count'),
      listingCount: _listings.length,
      reviewScore: ratingSummary.average ?? 0,
      reviewCount: ratingSummary.count,
      completedOrders: count('completed_orders'),
      photoUrl: photo.isNotEmpty ? photo : (isOwnProfile ? '' : visitor?.photoUrl ?? ''),
    );
  }

  // "03/14/2026" from the account's created_at, or empty when unknown.
  static String _joinedLabel(String createdAtText) {
    if (createdAtText.isEmpty) return '';
    final hasTimeZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(createdAtText);
    final createdAt = DateTime.tryParse(hasTimeZone ? createdAtText : '${createdAtText}Z')?.toLocal();
    if (createdAt == null) return '';
    return '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')}/${createdAt.year}';
  }

  Map<String, dynamic>? get loadedProfile => _loadedProfile;

  /// Whether the signed-in user follows this profile. Always false on their
  /// own profile and until the profile has loaded.
  bool get isFollowing => !isOwnProfile && _loadedProfile?['is_following'] == true;

  /// A follow or unfollow request is in flight; the button waits for it.
  bool isFollowBusy = false;

  /// Follows the profile, or unfollows it when already followed. The button
  /// and the follower count change at once and are put back if the server
  /// says no. Returns an error to show, or null.
  Future<String?> toggleFollow() async {
    final userId = subject?.userId;
    if (isOwnProfile || userId == null) return null;
    if (AuthService.currentUserId == null) return 'Log in to follow sellers.';
    if (isFollowBusy) return null;

    final wasFollowing = isFollowing;
    final follow = !wasFollowing;
    final followers = (_loadedProfile?['followers_count'] as num?)?.toInt() ?? 0;
    isFollowBusy = true;
    _followChanges++;
    _loadedProfile = {
      ...?_loadedProfile,
      'is_following': follow,
      'followers_count': follow ? followers + 1 : (followers > 0 ? followers - 1 : 0),
    };
    notifyListeners();
    try {
      final counts = follow ? await _profileService.follow(userId) : await _profileService.unfollow(userId);
      _loadedProfile = {...?_loadedProfile, ...counts};
      return null;
    } catch (error) {
      // Only the two values this changed go back; anything else that loaded
      // meanwhile stays.
      _loadedProfile = {...?_loadedProfile, 'is_following': wasFollowing, 'followers_count': followers};
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      isFollowBusy = false;
      _followChanges++;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    final userId = _subjectUserId;
    if (userId == null) return;
    final followChangesAtStart = _followChanges;
    try {
      var fetched = await _profileService.fetchProfile(userId);
      // A follow or unfollow started or landed while this was in flight, so
      // the server may have answered from before it. Everything else in the
      // answer is still taken; the follow state on screen is the newer one.
      final current = _loadedProfile;
      if (current != null && (isFollowBusy || followChangesAtStart != _followChanges)) {
        fetched = {
          ...fetched,
          for (final key in _followFields)
            if (current.containsKey(key)) key: current[key],
        };
      }
      _loadedProfile = isOwnProfile ? fetched : _withoutHiddenLocation(fetched);
      if (isOwnProfile) AuthService.updateCurrentUser(_loadedProfile!);
      notifyListeners();
    } catch (_) {
      // The cached login profile remains visible while the network is unavailable.
    }
  }

  static const List<String> _followFields = <String>['is_following', 'followers_count', 'following_count'];

  /// Goes up when a follow or unfollow starts and again when it lands, so a
  /// profile load can tell one happened while it was in flight.
  int _followChanges = 0;

  // Someone else's profile with "show location" off: their addresses say
  // where they are as plainly as the location line does, so neither is kept
  // for the page to build a location from.
  Map<String, dynamic> _withoutHiddenLocation(Map<String, dynamic> profile) {
    if (_normalizePrivacy(profile['profile_privacy'])['show_location'] != false) return profile;
    return Map<String, dynamic>.of(profile)
      ..remove('addresses')
      ..remove('preferred_address_id')
      ..remove('location');
  }

  /// Takes the profile an edit screen returned. Those answers carry what was
  /// edited, not always the whole profile (the photo upload has no addresses
  /// or follow counts), so they are laid over what is already known.
  Future<void> setProfile(Map<String, dynamic> profile) async {
    _loadedProfile = {...?_loadedProfile, ...profile};
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

  /// Whether the signed-in user is looking at their own account. The only
  /// case Lifetime Earnings may be loaded or shown in: buyers, guests and
  /// other sellers never get the figures, from the server or on screen.
  bool get isViewingOwnAccount {
    final me = AuthService.currentUserId;
    return isOwnProfile && me != null && _subjectUserId == me;
  }

  /// Lifetime earnings for the banner on the owner's profile.
  Future<void> loadEarnings() async {
    final userId = AuthService.currentUserId;
    if (!isViewingOwnAccount || userId == null) {
      earnings = null;
      return;
    }
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
    _disposed = true;
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

  // Leaving a profile while its listings are still loading disposes this
  // controller before the request settles.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
