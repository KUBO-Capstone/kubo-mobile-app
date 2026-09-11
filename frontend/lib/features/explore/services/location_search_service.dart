import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_result.dart';

/// Place search backed by OpenStreetMap's Nominatim, the geocoding counterpart
/// to the tile server the map already uses.
///
/// Nominatim's usage policy caps callers at roughly one request per second and
/// requires an identifying User-Agent, so callers must debounce typing. It is
/// suitable for development and demos; a production deployment should move to a
/// provider with a real quota.
class LocationSearchService {
  LocationSearchService({http.Client? client})
    : _client = client ?? http.Client();

  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  /// Required by the Nominatim usage policy so they can identify the caller.
  static const _userAgent = 'KuboMobileApp/1.0 (capstone project)';

  final http.Client _client;

  /// Searches Philippine places matching [query].
  Future<List<LocationResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return const <LocationResult>[];
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: <String, String>{
        'q': trimmed,
        'format': 'json',
        // Keep results inside the Philippines; Kubo is a domestic marketplace.
        'countrycodes': 'ph',
        'limit': '8',
      },
    );

    final response = await _client
        .get(uri, headers: const {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Location search failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <LocationResult>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LocationResult.fromNominatim)
        .where((result) => result.latitude != 0 || result.longitude != 0)
        .toList(growable: false);
  }

  void dispose() => _client.close();
}
