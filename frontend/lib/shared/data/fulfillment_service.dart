import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import '../../features/explore/models/bagsakan_center.dart';
import 'api_request.dart';

/// One bagsakan center, and whether this seller can drop off there.
class FulfillmentCenter {
  const FulfillmentCenter({required this.center, required this.supported});

  final BagsakanCenter center;
  final bool supported;
}

/// One courier, and whether this seller can book it from their area.
class FulfillmentCourier {
  const FulfillmentCourier({required this.name, required this.supported});

  final String name;
  final bool supported;
}

/// How a seller can hand produce over, from `GET /api/users/:id/fulfillment`.
/// The offer form only lets a buyer pick what is [FulfillmentCenter.supported]
/// or [FulfillmentCourier.supported].
class SellerFulfillment {
  const SellerFulfillment({
    required this.sellerId,
    required this.originLabel,
    required this.centers,
    required this.couriers,
    required this.configuredCenters,
    required this.configuredCouriers,
    this.productId,
    this.isListingOwn = false,
  });

  factory SellerFulfillment.fromJson(Map<String, dynamic> json) {
    return SellerFulfillment(
      sellerId: (json['seller_id'] as num).toInt(),
      productId: (json['product_id'] as num?)?.toInt(),
      isListingOwn: json['source'] == 'listing',
      originLabel: json['origin_label']?.toString() ?? '',
      centers: (json['centers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((row) => FulfillmentCenter(center: BagsakanCenter.fromJson(row), supported: row['supported'] != false))
          .toList(growable: false),
      couriers: (json['couriers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((row) => FulfillmentCourier(name: row['name']?.toString() ?? '', supported: row['supported'] != false))
          .where((courier) => courier.name.isNotEmpty)
          .toList(growable: false),
      configuredCenters: json['configured_centers'] == true,
      configuredCouriers: json['configured_couriers'] == true,
    );
  }

  final int sellerId;

  /// Set when these are the choices for one listing.
  final int? productId;

  /// The listing has its own choices; false means it follows the seller's
  /// profile.
  final bool isListingOwn;

  /// Where the produce starts from, e.g. "SILANG, CAVITE"; empty when the
  /// seller has no address yet.
  final String originLabel;
  final List<FulfillmentCenter> centers;
  final List<FulfillmentCourier> couriers;

  /// Whether the seller has narrowed the list down. Until they do, every
  /// center or courier counts as supported.
  final bool configuredCenters;
  final bool configuredCouriers;

  bool supportsCenter(String centerId) => centers.any((entry) => entry.center.id == centerId && entry.supported);
  bool supportsCourier(String name) => couriers.any((entry) => entry.name == name && entry.supported);
}

/// HTTP client for a seller's pickup and courier settings.
class FulfillmentService {
  FulfillmentService({http.Client? client}) : _client = client ?? apiClient();

  final http.Client _client;
  String get _baseUrl => ApiConfig.baseUrl;

  /// The choices on [sellerId]'s profile.
  Future<SellerFulfillment> fetch(int sellerId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('$_baseUrl/users/$sellerId/fulfillment')));
    return SellerFulfillment.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// What a buyer can pick on one listing: its own choices when the seller
  /// set them, the profile's otherwise. Public: the offer form reads it.
  Future<SellerFulfillment> fetchForListing(int productId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('$_baseUrl/products/$productId/fulfillment')));
    return SellerFulfillment.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// The seller gives one listing its own choices ([custom] true), or sends
  /// it back to following the profile ([custom] false). The profile's
  /// choices are never changed by this.
  Future<SellerFulfillment> saveForListing({
    required int productId,
    required bool custom,
    List<int> centerIds = const <int>[],
    List<String> couriers = const <String>[],
  }) async {
    final response = await sendRequest(
      () => _client.put(
        Uri.parse('$_baseUrl/products/$productId/fulfillment'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'custom': custom, 'center_ids': centerIds, 'couriers': couriers}),
      ),
    );
    return SellerFulfillment.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// The signed-in seller saves their profile lists. An empty list means
  /// "not narrowed down": buyers may pick any. Listings with their own
  /// choices keep them.
  Future<SellerFulfillment> save({
    required int sellerId,
    required List<int> centerIds,
    required List<String> couriers,
  }) async {
    final response = await sendRequest(
      () => _client.put(
        Uri.parse('$_baseUrl/users/$sellerId/fulfillment'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'center_ids': centerIds, 'couriers': couriers}),
      ),
    );
    return SellerFulfillment.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
