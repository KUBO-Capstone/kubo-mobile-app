import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

/// HTTP client for the backend account and login endpoints.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  // Select the active value with:
  // flutter run --dart-define=API_BASE_URL=http://HOST:3000/api
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  // USB Android with adb reverse and the iOS simulator use the host loopback.
  static const _defaultBaseUrl = 'http://localhost:3000/api';

  // Android emulator alternative:
  // static const _defaultBaseUrl = 'http://10.0.2.2:3000/api';

  // Physical Android/iPhone alternative: replace HOST with the computer's LAN IP.
  // static const _defaultBaseUrl = 'http://192.168.1.7:3000/api';

  String get _baseUrl =>
      _configuredBaseUrl.isNotEmpty ? _configuredBaseUrl : _defaultBaseUrl;

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
      throw Exception(
        'Cannot reach the Kubo server. Check that the backend is running and the phone is on the same network.',
      );
    }
  }

  void dispose() => _client.close();
}
