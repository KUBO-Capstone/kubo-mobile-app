import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/formatters.dart';
import 'package:frontend/shared/data/earnings_service.dart';
import 'package:frontend/shared/data/message_service.dart';
import 'package:frontend/shared/data/order_service.dart';
import 'package:frontend/shared/data/review_service.dart';

Map<String, dynamic> _reviewJson({int rating = 5, String role = 'buyer'}) => {
      'review_id': 1,
      'order_id': 12,
      'reviewer_id': 7,
      'reviewee_id': 3,
      'reviewer_name': 'Juan Dela Cruz',
      'reviewer_photo_url': '/uploads/profile/juan.jpg',
      'reviewer_role': role,
      'rating': rating,
      'comment': 'Sobrang fresh!',
      'tags': ['fresh', 'on_time'],
      'product_id': 8,
      'crop_name': 'Calamansi',
      'product_image': null,
      'created_at': '2026-10-29 08:23:11',
    };

Map<String, dynamic> _orderJson({String status = 'delivered', Object? myReview, Object? theirReview}) => {
      'order_id': 12,
      'negotiation_id': 5,
      'conversation_id': 4,
      'buyer_id': 7,
      'seller_id': 3,
      'buyer_name': 'Juan Dela Cruz',
      'seller_name': 'Maria Santos',
      'product_id': 8,
      'crop_name': 'Calamansi',
      'unit_measurement': 'kg',
      'quantity': 10,
      'negotiated_price': 80,
      'total_amount': 800,
      'order_status': status,
      'delivery_method': 'courier',
      'order_date': '2026-10-29 08:00:00',
      'updated_at': '2026-10-29 08:00:00',
      'my_review': myReview,
      'their_review': theirReview,
    };

void main() {
  group('formatters', () {
    test('formatPeso groups thousands and keeps cents only when needed', () {
      expect(formatPeso(3100), '₱3,100');
      expect(formatPeso(0), '₱0');
      expect(formatPeso(999), '₱999');
      expect(formatPeso(1234567.5), '₱1,234,567.50');
      expect(formatPeso(73.9), '₱73.90');
    });

    test('parseServerTime reads SQLite timestamps as UTC', () {
      expect(parseServerTime('2026-10-29 08:23:11')!.toUtc(), DateTime.utc(2026, 10, 29, 8, 23, 11));
      expect(parseServerTime('2026-10-29T08:23:11.000Z')!.toUtc(), DateTime.utc(2026, 10, 29, 8, 23, 11));
      expect(parseServerTime(null), isNull);
    });

    test('timeAgo steps from minutes to a month label', () {
      final now = DateTime(2026, 10, 29, 12);
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
      expect(timeAgo(now.subtract(const Duration(days: 15)), now: now), '2w ago');
      expect(timeAgo(DateTime(2026, 3, 2), now: now), 'Mar 2026');
    });
  });

  test('reviews and their summary parse from the API', () {
    final reviews = UserReviews.fromJson({
      'summary': {'average': 4.5, 'count': 2, 'breakdown': {'1': 0, '2': 0, '3': 0, '4': 1, '5': 1}},
      'reviews': [_reviewJson(), _reviewJson(rating: 4, role: 'seller')],
    });
    expect(reviews.summary.average, 4.5);
    expect(reviews.summary.hasReviews, isTrue);
    expect(reviews.summary.breakdown, {1: 0, 2: 0, 3: 0, 4: 1, 5: 1});
    final first = reviews.reviews.first;
    expect(first.reviewerRole, ReviewerRole.buyer);
    expect(first.tags, ['fresh', 'on_time']);
    expect(first.reviewerPhotoUrl, endsWith('/uploads/profile/juan.jpg'));
    expect(first.createdAt!.toUtc(), DateTime.utc(2026, 10, 29, 8, 23, 11));
    expect(reviews.reviews.last.reviewerRole, ReviewerRole.seller);
    expect(ReviewTags.labelOf('fresh'), 'Fresh produce');
    expect(RatingSummary.fromJson(const {'average': null, 'count': 0}).hasReviews, isFalse);
  });

  test('an order can be reviewed once delivered, until the viewer has reviewed it', () {
    final delivered = OrderRecord.fromJson(_orderJson());
    expect(delivered.canReview(7), isTrue);
    expect(delivered.canReview(3), isTrue);
    expect(delivered.canReview(99), isFalse);
    expect(OrderRecord.fromJson(_orderJson(status: 'in transit')).canReview(7), isFalse);

    final reviewed = OrderRecord.fromJson(_orderJson(myReview: _reviewJson(), theirReview: _reviewJson(rating: 4, role: 'seller')));
    expect(reviewed.canReview(7), isFalse);
    expect(reviewed.myReview!.rating, 5);
    expect(reviewed.theirReview!.rating, 4);
  });

  test('a conversation carries the celebration flag, ratings, and deal methods', () {
    final thread = ConversationRecord.fromJson({
      'conversation_id': 4,
      'buyer_id': 7,
      'seller_id': 3,
      'buyer_name': 'Juan Dela Cruz',
      'seller_name': 'Maria Santos',
      'product_id': 8,
      'crop_name': 'Calamansi',
      'base_price': 90,
      'unit_measurement': 'kg',
      'product_status': 'available',
      'allows_meetup': false,
      'allows_delivery': true,
      'seller_location': 'Quezon City',
      'is_unread': false,
      'negotiation_id': 5,
      'negotiation_status': 'accepted',
      'offered_price': 80,
      'offered_quantity': 10,
      'accepted_by': 3,
      'celebration_pending': true,
      'order_id': 12,
      'order_status': 'delivered',
      'my_review_rating': null,
      'buyer_rating': 4.0,
      'buyer_review_count': 1,
      'seller_rating': 5.0,
      'seller_review_count': 3,
    });
    expect(thread.celebrationPending, isTrue);
    expect(thread.acceptedBy, 3);
    expect(thread.counterpartyRating(7), 5.0);
    expect(thread.counterpartyReviewCount(7), 3);
    expect(thread.counterpartyRating(3), 4.0);
    expect(thread.canReviewOrder(7), isTrue);
    // The order page reads deal methods from this bridge when ordering from chat.
    expect(thread.negotiation!.allowsMeetup, isFalse);
    expect(thread.negotiation!.allowsDelivery, isTrue);
  });

  test('earnings parse with their top listings', () {
    final summary = EarningsSummary.fromJson({
      'total_earned': 3100,
      'completed_orders': 4,
      'in_progress_total': 520,
      'in_progress_deals': 2,
      'first_sale_at': '2026-03-02 09:00:00',
      'top_listings': [
        {
          'product_id': 8,
          'crop_name': 'Calamansi',
          'unit_measurement': 'kg',
          'product_status': 'available',
          'product_image': '/uploads/products/a.jpg',
          'earned': 1500,
          'quantity_sold': 20,
          'orders': 2,
        },
      ],
    });
    expect(summary.totalEarned, 3100);
    expect(summary.firstSaleAt!.toUtc().month, 3);
    expect(summary.topListings.single.productImage, endsWith('/uploads/products/a.jpg'));
    expect(summary.topListings.single.quantitySold, 20);
  });
}
