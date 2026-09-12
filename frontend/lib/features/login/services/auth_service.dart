import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';

/// HTTP client for the backend account and login endpoints.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _client;

  static Map<String, dynamic>? currentUser;

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String contactNumber,
  }) async {
    final response = await _post('/auth/register', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'contact_number': contactNumber,
    });

    _checkResponse(response);
    final user = (jsonDecode(response.body) as Map<String, dynamic>)['data']
      as Map<String, dynamic>;
    currentUser = user;
    return user;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    _checkResponse(response);
    final user = jsonDecode(response.body)['data'] as Map<String, dynamic>;
    currentUser = user;
    return user;
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? 'Request failed');
  }

  Future<http.Response> _post(String path, Map<String, String> body) async {
    try {
      return await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(_unreachableMessage);
    } on http.ClientException {
      // package:http wraps a refused/reset socket in ClientException; the raw
      // text is an errno dump, so replace it with something actionable.
      throw Exception(_unreachableMessage);
    }
  }

  String get _unreachableMessage =>
      'Cannot reach the Kubo server at $_baseUrl. Check that the backend is '
      'running (`npm run dev` in backend/) and, on a physical phone, that '
      'API_BASE_URL points at the LAN IP of this machine.';

  void dispose() => _client.close();
}
