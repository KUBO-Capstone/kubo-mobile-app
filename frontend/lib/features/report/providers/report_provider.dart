import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../../../shared/data/api_request.dart';

class ReportService {
  ReportService({http.Client? client}) : _client = client ?? apiClient();

  final http.Client _client;

  /// App feedback or a bug report, from the drawer's Report page.
  Future<void> submit({
    required String name,
    required String category,
    required String message,
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}/reports'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'category': category,
          'message': message,
        }),
      ),
    );
    checkResponse(response);
  }

  /// Reports a listing. Throws with the server's message when it is refused,
  /// for example when the user has already reported it.
  Future<void> reportListing({required int productId, required String reason}) =>
      _fileReport('${ApiConfig.baseUrl}/reports/listings/$productId', reason);

  /// Reports an account.
  Future<void> reportUser({required int userId, required String reason}) =>
      _fileReport('${ApiConfig.baseUrl}/reports/users/$userId', reason);

  Future<void> _fileReport(String url, String reason) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason}),
      ),
    );
    checkResponse(response);
  }

  void dispose() => _client.close();
}
