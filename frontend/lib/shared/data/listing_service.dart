import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';
import 'synthetic_records.dart';

class ListingService {
  ListingService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  /// [includeUnavailable] also returns the seller's sold-out listings; only
  /// the owner's profile tab asks for them.
  Future<List<SyntheticListingRecord>> fetchListings({
    String query = '',
    int? sellerId,
    bool includeUnavailable = false,
  }) async {
    final queryParameters = <String, String>{};
    if (query.trim().isNotEmpty) queryParameters['q'] = query.trim();
    if (sellerId != null) queryParameters['seller_id'] = '$sellerId';
    if (includeUnavailable) queryParameters['include_unavailable'] = 'true';
    final uri = Uri.parse('$_baseUrl/products').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SyntheticListingRecord.fromJson)
        .toList(growable: false);
  }

  /// One listing by id, whatever its status (the chat header links to it
  /// even after it is sold out).
  Future<SyntheticListingRecord> fetchListing(int productId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('$_baseUrl/products/$productId')));
    return SyntheticListingRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Lists produce as the signed-in user.
  Future<SyntheticListingRecord> createListing({
    required String cropName,
    required String category,
    required double price,
    required double quantity,
    required String unit,
    List<String> images = const <String>[],
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'crop_name': cropName,
          'category': category,
          'base_price': price,
          'available_quantity': quantity,
          'unit_measurement': unit,
          'images': images,
        }),
      ),
    );
    return SyntheticListingRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Seller edits the listing's details. Only non-null fields are sent.
  Future<SyntheticListingRecord> updateListing({
    required int productId,
    String? cropName,
    String? category,
    double? price,
    double? quantity,
    String? unit,
  }) {
    return _patch(productId, {
      if (cropName != null) 'crop_name': cropName,
      if (category != null) 'category': category,
      if (price != null) 'base_price': price,
      if (quantity != null) 'available_quantity': quantity,
      if (unit != null) 'unit_measurement': unit,
    });
  }

  /// Marks the listing sold out ([soldOut] true) or available again.
  Future<SyntheticListingRecord> setSoldOut({
    required int productId,
    required bool soldOut,
  }) {
    return _patch(productId, {
      'status': soldOut ? 'out of stock' : 'available',
    });
  }

  /// Removes the listing from every view. The backend delists rather than
  /// deletes so buyers' past offers on it still resolve.
  Future<void> removeListing({required int productId}) async {
    final response = await sendRequest(
      () => _client.delete(Uri.parse('$_baseUrl/products/$productId')),
    );
    checkResponse(response);
  }

  Future<SyntheticListingRecord> _patch(int productId, Map<String, dynamic> body) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('$_baseUrl/products/$productId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return SyntheticListingRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}