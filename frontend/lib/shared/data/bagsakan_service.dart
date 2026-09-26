import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import '../../features/explore/models/bagsakan_center.dart';
import 'api_request.dart';

/// HTTP client for the bagsakan drop-off center endpoints.
class BagsakanService {
  BagsakanService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Future<List<BagsakanCenter>> fetchCenters({String query = ''}) async {
    final queryParameters = <String, String>{};
    if (query.trim().isNotEmpty) queryParameters['q'] = query.trim();
    final uri = Uri.parse('$_baseUrl/bagsakan-centers').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(BagsakanCenter.fromJson)
        .toList(growable: false);
  }

  void dispose() => _client.close();
}
