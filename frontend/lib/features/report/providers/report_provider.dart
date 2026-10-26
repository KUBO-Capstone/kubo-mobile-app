import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../../../shared/data/api_request.dart';

class ReportService {
  ReportService({http.Client? client}) : _client = client ?? apiClient();

  final http.Client _client;

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

  void dispose() => _client.close();
}