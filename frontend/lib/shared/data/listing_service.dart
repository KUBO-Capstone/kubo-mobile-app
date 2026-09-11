import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'synthetic_records.dart';

class ListingService {
  ListingService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Future<List<SyntheticListingRecord>> fetchListings({String query = '', int? sellerId}) async {
    final queryParameters = <String, String>{};
    if (query.trim().isNotEmpty) queryParameters['q'] = query.trim();
    if (sellerId != null) queryParameters['seller_id'] = '$sellerId';
    final uri = Uri.parse('$_baseUrl/products').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    _checkResponse(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SyntheticListingRecord.fromJson)
        .toList(growable: false);
  }

  Future<SyntheticListingRecord> createListing({
    required int sellerId,
    required String cropName,
    required String category,
    required double price,
    required double quantity,
    required String unit,
    List<String> images = const <String>[],
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'seller_id': sellerId,
        'crop_name': cropName,
        'category': category,
        'base_price': price,
        'available_quantity': quantity,
        'unit_of_measure': unit,
        'images': images,
      }),
    ).timeout(const Duration(seconds: 15));
    _checkResponse(response);
    return SyntheticListingRecord.fromJson(
      (jsonDecode(response.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? 'Request failed');
  }

  void dispose() => _client.close();
}