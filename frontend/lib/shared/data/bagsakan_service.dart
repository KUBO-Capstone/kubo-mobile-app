import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import '../../features/explore/models/bagsakan_center.dart';

/// HTTP client for the bagsakan drop-off center endpoints.
class BagsakanService {
  BagsakanService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Future<List<BagsakanCenter>> fetchCenters({String query = ''}) async {
    final queryParameters = <String, String>{};
    if (query.trim().isNotEmpty) queryParameters['q'] = query.trim();
    final uri = Uri.parse('$_baseUrl/bagsakan-centers').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    _checkResponse(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(BagsakanCenter.fromJson)
        .toList(growable: false);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? 'Request failed');
  }

  void dispose() => _client.close();
}
