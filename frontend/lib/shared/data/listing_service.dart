import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';
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
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
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
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seller_id': sellerId,
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

  void dispose() => _client.close();
}