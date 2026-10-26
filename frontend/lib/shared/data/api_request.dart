import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';

/// Shared plumbing for the API clients: one timeout, one "server unreachable"
/// message, and one place that turns a non-2xx body into an [Exception] carrying
/// the backend's `message`.
///
/// Every service should send through [sendRequest] rather than calling the
/// client directly so a refused socket never surfaces as a raw
/// `ClientException with SocketException…` string.
const Duration apiTimeout = Duration(seconds: 15);

/// The signed-in user's bearer token. `AuthService` sets it on login/register
/// and clears it on logout; [apiClient] reads it on every request.
abstract final class ApiSession {
  static String? token;
}

/// The default client for every API service: stamps `Authorization: Bearer`
/// on each request while someone is signed in, so no service ever passes the
/// user's id itself - the server reads identity from the token.
http.Client apiClient() => _AuthorizedClient(http.Client());

class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final token = ApiSession.token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

String get unreachableServerMessage =>
    'Cannot reach the Kubo server at ${ApiConfig.baseUrl}. Check that the '
    'backend is running (`npm run dev` in backend/) and, on a physical phone, '
    'that API_BASE_URL points at the LAN IP of this machine.';

Future<http.Response> sendRequest(Future<http.Response> Function() send) async {
  try {
    return await send().timeout(apiTimeout);
  } on TimeoutException {
    throw Exception(unreachableServerMessage);
  } on http.ClientException {
    // package:http wraps a refused/reset socket in ClientException; the raw
    // text is an errno dump, so replace it with something actionable.
    throw Exception(unreachableServerMessage);
  }
}

/// Throws with the backend's `message` for any non-2xx response.
void checkResponse(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  String message = 'Request failed (${response.statusCode})';
  try {
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic> && body['message'] is String) {
      message = body['message'] as String;
    }
  } on FormatException {
    // Non-JSON error page; keep the status-code message.
  }
  throw Exception(message);
}

/// Decodes a `{ success, data }` envelope and returns `data`.
dynamic readData(http.Response response) {
  checkResponse(response);
  return (jsonDecode(response.body) as Map<String, dynamic>)['data'];
}
