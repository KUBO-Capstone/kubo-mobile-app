import 'synthetic_records.dart';

/// Synthetic profile metadata shared by own-account and visitor profile views.
class SyntheticProfileRecord {
  const SyntheticProfileRecord({
    required this.displayName,
    required this.username,
    required this.locationLabel,
    required this.about,
    required this.joinedLabel,
    required this.followingCount,
    required this.followersCount,
    required this.listingCount,
    required this.reviewScore,
    required this.reviewCount,
    this.photoUrl = '',
  });

  /// Name shown in the profile header.
  final String displayName;

  /// Handle shown under the profile name.
  final String username;

  /// City or region label shown in the about section.
  final String locationLabel;

  /// Short about text displayed in the about tab.
  final String about;

  /// Human-readable join date label.
  final String joinedLabel;

  /// Number of followed accounts shown in the profile summary.
  final int followingCount;

  /// Number of followers shown in the profile summary.
  final int followersCount;

  /// Number of listings shown in the profile summary.
  final int listingCount;

  /// Average rating shown in the reviews tab.
  final double reviewScore;

  /// Review count shown in the reviews tab.
  final int reviewCount;

  final String photoUrl;
}

/// Synthetic review record for the profile reviews tab.
class SyntheticProfileReviewRecord {
  const SyntheticProfileReviewRecord({
    required this.reviewerName,
    required this.rating,
    required this.timeLabel,
    required this.message,
    required this.productName,
    required this.productPrice,
    this.imageAssets = const <String>[],
  });

  /// Name of the user who posted the review.
  final String reviewerName;

  /// Star rating used for the review row.
  final double rating;

  /// Relative time label shown beside the stars.
  final String timeLabel;

  /// Review body text.
  final String message;

  /// Product name referenced in the review.
  final String productName;

  /// Product price referenced in the review.
  final String productPrice;

  /// Optional image assets attached to the review.
  final List<String> imageAssets;
}

/// Synthetic profile shown in the own-account and visitor profile pages.
const syntheticProfileRecord = SyntheticProfileRecord(
  displayName: 'Display Name',
  username: '@username',
  locationLabel: 'Caloocan',
  about:
      'So don\'t call me baby, Unless you mean it, Don\'t tell me you need me, If you don\'t believe it, So let me know the truth, Before I dive right into you',
  joinedLabel: 'June 2025',
  followingCount: 33,
  followersCount: 20,
  listingCount: 3,
  reviewScore: 5.0,
  reviewCount: 5,
  photoUrl: '',
);

/// Synthetic listings surfaced in the profile listings tab.
final List<SyntheticListingRecord> syntheticProfileListings =
    <SyntheticListingRecord>[
      const SyntheticListingRecord(
        id: 'profile-listing-0',
        title: 'Product name placeholder product name placeholder',
        price: 'PHP XX,XXX',
        locationLabel: 'Caybiga',
        regionLabel: 'NCR',
        sellerLabel: 'Username',
        imageAssetPath: 'assets/images/Placeholder_img.png',
        description: 'Placeholder description for a profile listing.',
        date: 'Posted today',
        numLikes: 12,
        groups: <String>['vegetables'],
      ),
      const SyntheticListingRecord(
        id: 'profile-listing-1',
        title: 'Product name placeholder product name placeholder',
        price: 'PHP XX,XXX',
        locationLabel: 'Caybiga',
        regionLabel: 'NCR',
        sellerLabel: 'Username',
        imageAssetPath: 'assets/images/Placeholder_img.png',
        description: 'Placeholder description for a profile listing.',
        date: 'Posted 2 days ago',
        numLikes: 18,
        groups: <String>['fruits'],
      ),
      const SyntheticListingRecord(
        id: 'profile-listing-2',
        title: 'Product name placeholder product name placeholder',
        price: 'PHP XX,XXX',
        locationLabel: 'Caybiga',
        regionLabel: 'NCR',
        sellerLabel: 'Username',
        imageAssetPath: 'assets/images/Placeholder_img.png',
        description: 'Placeholder description for a profile listing.',
        date: 'Posted 4 days ago',
        numLikes: 22,
        groups: <String>['grains'],
      ),
    ];

/// Synthetic reviews surfaced in the reviews tab.
final List<SyntheticProfileReviewRecord>
syntheticProfileReviews = <SyntheticProfileReviewRecord>[
  const SyntheticProfileReviewRecord(
    reviewerName: 'Ariamrhod',
    rating: 5,
    timeLabel: '1 year ago',
    message:
        'You\'d think I\'d be a fast learner. But guess I won\'t ever mind crisping up on your backburner',
    productName: 'Product name',
    productPrice: 'PHP XX,XXX',
    imageAssets: <String>[
      'assets/images/Placeholder_img.png',
      'assets/images/Placeholder_img.png',
    ],
  ),
  const SyntheticProfileReviewRecord(
    reviewerName: 'Andreameda Galaxy',
    rating: 5,
    timeLabel: '1 year ago',
    message: 'i will take sir duncan side',
    productName: 'Product name',
    productPrice: 'PHP XX,XXX',
  ),
];
