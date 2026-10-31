import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import '../../core/utils/formatters.dart';
import 'api_request.dart';

/// One listing in "Your top earning listings".
class TopEarningListing {
  const TopEarningListing({
    required this.productId,
    required this.cropName,
    required this.unit,
    required this.status,
    required this.earned,
    required this.quantitySold,
    required this.orders,
    this.productImage,
  });

  factory TopEarningListing.fromJson(Map<String, dynamic> json) => TopEarningListing(
        productId: (json['product_id'] as num).toInt(),
        cropName: json['crop_name']?.toString() ?? 'Listing',
        unit: json['unit_measurement']?.toString() ?? '',
        status: json['product_status']?.toString() ?? 'available',
        productImage: resolveMediaUrl(json['product_image']?.toString()),
        earned: (json['earned'] as num?)?.toDouble() ?? 0,
        quantitySold: (json['quantity_sold'] as num?)?.toDouble() ?? 0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );

  final int productId;
  final String cropName;
  final String unit;

  /// `available`, `out of stock`, or `delisted`.
  final String status;
  final String? productImage;
  final double earned;
  final double quantitySold;
  final int orders;
}

/// The seller's own estimate from `GET /api/users/:id/earnings`.
class EarningsSummary {
  const EarningsSummary({
    required this.totalEarned,
    required this.completedOrders,
    required this.inProgressTotal,
    required this.inProgressDeals,
    required this.topListings,
    this.firstSaleAt,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) => EarningsSummary(
        totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0,
        completedOrders: (json['completed_orders'] as num?)?.toInt() ?? 0,
        inProgressTotal: (json['in_progress_total'] as num?)?.toDouble() ?? 0,
        inProgressDeals: (json['in_progress_deals'] as num?)?.toInt() ?? 0,
        firstSaleAt: parseServerTime(json['first_sale_at']?.toString()),
        topListings: (json['top_listings'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TopEarningListing.fromJson)
            .toList(growable: false),
      );

  /// Delivered orders: produce handed over, payment settled in person.
  final double totalEarned;
  final int completedOrders;

  /// Open orders plus accepted offers that are not orders yet.
  final double inProgressTotal;
  final int inProgressDeals;
  final DateTime? firstSaleAt;
  final List<TopEarningListing> topListings;
}

class EarningsService {
  EarningsService({http.Client? client}) : _client = client ?? apiClient();

  final http.Client _client;

  /// Only works for the signed-in user's own id; the server refuses others.
  Future<EarningsSummary> fetchEarnings(int userId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('${ApiConfig.baseUrl}/users/$userId/earnings')));
    return EarningsSummary.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
