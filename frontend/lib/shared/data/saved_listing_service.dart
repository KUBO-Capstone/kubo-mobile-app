import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';
import 'synthetic_records.dart';

/// HTTP client for `/api/saved-listings` (the heart on listing cards).
///
/// KNOWN DEBT: `user_id` goes in the request because there is no auth token
/// yet; drop it here when Phase 2 lands.
class SavedListingService {
  SavedListingService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Map<String, String> get _json => const {'Content-Type': 'application/json'};

  /// The user's saved listings, newest save first. Sold-out rows are included
  /// (the buyer was tracking them); delisted ones are not.
  Future<List<SyntheticListingRecord>> fetchSaved({required int userId}) async {
    final uri = Uri.parse('$_baseUrl/saved-listings').replace(queryParameters: {'user_id': '$userId'});
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SyntheticListingRecord.fromJson)
        .toList(growable: false);
  }

  /// Just the product ids, enough to paint the hearts on every grid.
  Future<Set<int>> fetchSavedIds({required int userId}) async {
    final uri = Uri.parse('$_baseUrl/saved-listings')
        .replace(queryParameters: {'user_id': '$userId', 'ids_only': 'true'});
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>).whereType<num>().map((id) => id.toInt()).toSet();
  }

  Future<void> save({required int userId, required int productId}) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/saved-listings'),
        headers: _json,
        body: jsonEncode({'user_id': userId, 'product_id': productId}),
      ),
    );
    checkResponse(response);
  }

  Future<void> unsave({required int userId, required int productId}) async {
    final response = await sendRequest(
      () => _client.delete(
        Uri.parse('$_baseUrl/saved-listings/$productId'),
        headers: _json,
        body: jsonEncode({'user_id': userId}),
      ),
    );
    checkResponse(response);
  }

  void dispose() => _client.close();
}
