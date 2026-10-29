import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import '../../core/utils/formatters.dart';
import 'api_request.dart';

/// The reviewer's side of the order. A [buyer] review rates a seller.
enum ReviewerRole { buyer, seller }

/// A quick tag picked with a rating. [key] is what the backend stores.
class ReviewTag {
  const ReviewTag(this.key, this.label);

  final String key;
  final String label;
}

/// Mirrors `sellerReviewTags` / `buyerReviewTags` in the backend review model.
abstract final class ReviewTags {
  /// What a buyer can say about a seller and their produce.
  static const aboutSeller = <ReviewTag>[
    ReviewTag('fresh', 'Fresh produce'),
    ReviewTag('as_described', 'As described'),
    ReviewTag('well_packed', 'Well packed'),
    ReviewTag('on_time', 'On time'),
    ReviewTag('fair_price', 'Fair price'),
    ReviewTag('friendly', 'Friendly'),
  ];

  /// What a seller can say about a buyer.
  static const aboutBuyer = <ReviewTag>[
    ReviewTag('smooth_deal', 'Smooth deal'),
    ReviewTag('on_time', 'On time'),
    ReviewTag('clear_communication', 'Clear communication'),
    ReviewTag('friendly', 'Friendly'),
  ];

  static String labelOf(String key) {
    for (final tag in [...aboutSeller, ...aboutBuyer]) {
      if (tag.key == key) return tag.label;
    }
    return key;
  }
}

/// Words for each star count, shown while picking a rating.
const ratingLabels = <int, String>{
  1: 'Poor',
  2: 'Fair',
  3: 'Good',
  4: 'Very good',
  5: 'Excellent',
};

/// One review, as returned by `GET /api/users/:id/reviews` and on orders.
class ReviewRecord {
  const ReviewRecord({
    required this.id,
    required this.orderId,
    required this.reviewerId,
    required this.revieweeId,
    required this.reviewerName,
    required this.reviewerRole,
    required this.rating,
    required this.comment,
    required this.tags,
    required this.productId,
    required this.cropName,
    this.reviewerPhotoUrl,
    this.productImage,
    this.createdAt,
  });

  factory ReviewRecord.fromJson(Map<String, dynamic> json) {
    return ReviewRecord(
      id: (json['review_id'] as num).toInt(),
      orderId: (json['order_id'] as num).toInt(),
      reviewerId: (json['reviewer_id'] as num).toInt(),
      revieweeId: (json['reviewee_id'] as num).toInt(),
      reviewerName: json['reviewer_name']?.toString() ?? 'Kubo user',
      reviewerPhotoUrl: resolveMediaUrl(json['reviewer_photo_url']?.toString()),
      reviewerRole: json['reviewer_role'] == 'seller' ? ReviewerRole.seller : ReviewerRole.buyer,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment']?.toString() ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[]).whereType<String>().toList(growable: false),
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      cropName: json['crop_name']?.toString() ?? 'Listing',
      productImage: resolveMediaUrl(json['product_image']?.toString()),
      createdAt: parseServerTime(json['created_at']?.toString()),
    );
  }

  final int id;
  final int orderId;
  final int reviewerId;
  final int revieweeId;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final ReviewerRole reviewerRole;

  /// 1 to 5.
  final int rating;
  final String comment;

  /// Keys from [ReviewTags].
  final List<String> tags;
  final int productId;
  final String cropName;
  final String? productImage;
  final DateTime? createdAt;
}

/// Average and star breakdown for one user.
class RatingSummary {
  const RatingSummary({required this.average, required this.count, required this.breakdown});

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['breakdown'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return RatingSummary(
      average: (json['average'] as num?)?.toDouble(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      breakdown: {for (var star = 1; star <= 5; star++) star: (raw['$star'] as num?)?.toInt() ?? 0},
    );
  }

  static const empty = RatingSummary(average: null, count: 0, breakdown: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});

  /// Null until the first review.
  final double? average;
  final int count;

  /// Reviews per star, 1 to 5.
  final Map<int, int> breakdown;

  bool get hasReviews => count > 0 && average != null;
}

class UserReviews {
  const UserReviews({required this.summary, required this.reviews});

  factory UserReviews.fromJson(Map<String, dynamic> json) => UserReviews(
        summary: RatingSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
        reviews: (json['reviews'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ReviewRecord.fromJson)
            .toList(growable: false),
      );

  static const empty = UserReviews(summary: RatingSummary.empty, reviews: <ReviewRecord>[]);

  final RatingSummary summary;
  final List<ReviewRecord> reviews;
}

class ReviewService {
  ReviewService({http.Client? client}) : _client = client ?? apiClient();

  final http.Client _client;
  String get _baseUrl => ApiConfig.baseUrl;

  /// Everything a profile's Reviews tab shows. Public: no sign-in needed.
  Future<UserReviews> fetchUserReviews(int userId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('$_baseUrl/users/$userId/reviews')));
    return UserReviews.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Rates the other party on a delivered order.
  Future<ReviewRecord> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
    List<String> tags = const <String>[],
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/orders/$orderId/review'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'rating': rating, 'comment': comment.trim(), 'tags': tags}),
      ),
    );
    return ReviewRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
