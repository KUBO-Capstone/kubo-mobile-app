import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../../../shared/data/api_request.dart';

/// HTTP client for the backend account and login endpoints.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _client;

  static Map<String, dynamic>? currentUser;

  /// Numeric id of the signed-in user, or null when nobody is logged in.
  static int? get currentUserId =>
      int.tryParse(currentUser?['user_id']?.toString() ?? '');

  static void updateCurrentUser(Map<String, dynamic> user) {
    currentUser = user;
  }

  /// Ends the in-memory session. There is no server-side session to end
  /// yet; callers also clear any per-user caches (saved listings) and
  /// rebuild the navigator so nothing from the old account stays mounted.
  static void logout() {
    currentUser = null;
    ApiSession.token = null;
  }

  /// Login and register both answer with the user row plus a `token`; the
  /// token goes to [ApiSession] and the rest becomes [currentUser].
  static Map<String, dynamic> _startSession(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.of(data);
    ApiSession.token = user.remove('token') as String?;
    currentUser = user;
    return user;
  }

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

    return _startSession(readData(response) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    return _startSession(readData(response) as Map<String, dynamic>);
  }

  Future<http.Response> _post(String path, Map<String, String> body) {
    return sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  void dispose() => _client.close();
}
