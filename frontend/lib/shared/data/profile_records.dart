/// What a profile page shows about an account, own or visited. Built by
/// `ProfilePageController.profile` from the account's data; a text field the
/// account has not filled in is an empty string, and the page decides what
/// to show in its place.
class SyntheticProfileRecord {
  const SyntheticProfileRecord({
    required this.displayName,
    required this.username,
    required this.locationLabel,
    required this.about,
    this.businessName = '',
    this.businessType = '',
    this.profilePrivacy = const <String, bool>{
      'public_profile': true,
      'show_bio': true,
      'show_contact_number': true,
      'show_location': true,
    },
    required this.joinedLabel,
    required this.followingCount,
    required this.followersCount,
    required this.listingCount,
    required this.reviewScore,
    required this.reviewCount,
    this.completedOrders = 0,
    this.photoUrl = '',
    this.contactNumber = '',
  });

  /// Name shown in the profile header.
  final String displayName;

  /// Handle shown under the profile name; empty when the account hides it.
  final String username;

  /// City or region label shown in the about section; empty when unknown.
  final String locationLabel;

  /// Optional business identity shown in the profile details.
  final String businessName;

  /// Optional business category shown in the profile details.
  final String businessType;

  /// Privacy toggles for the profile visibility breakdown.
  final Map<String, bool> profilePrivacy;

  /// The account's bio; empty until they write one.
  final String about;

  /// Date the account was created, e.g. "03/14/2026"; empty when unknown.
  final String joinedLabel;

  /// How many accounts this one follows.
  final int followingCount;

  /// How many accounts follow this one.
  final int followersCount;

  /// Number of listings shown in the profile summary.
  final int listingCount;

  /// Average rating shown in the reviews tab.
  final double reviewScore;

  /// Review count shown in the reviews tab.
  final int reviewCount;

  /// Orders this account bought or sold that reached the buyer. Public: it
  /// is a trust signal, unlike the seller's earnings, which never leave
  /// their own profile.
  final int completedOrders;

  final String photoUrl;

  /// Shown in About when the account allows it; empty otherwise.
  final String contactNumber;

  /// The account hides everything but its name and photo from others.
  bool get isPrivate => profilePrivacy['public_profile'] == false;
}
