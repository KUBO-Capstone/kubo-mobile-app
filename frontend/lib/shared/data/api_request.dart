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

  static final StreamController<void> _expired = StreamController<void>.broadcast();

  /// Fires once when the server refuses the token the app is using: it ran
  /// out, or the account is gone. The app answers by signing the user out
  /// (see `KuboApp`), since a session kept from an earlier launch can no
  /// longer be assumed to be good.
  static Stream<void> get expired => _expired.stream;

  /// Called by [apiClient] when a request sent with [rejected] came back as
  /// an invalid-token 401. Ignored when the app has moved on to another
  /// token (a new login) or already signed out, so several requests failing
  /// together report it once.
  static void reportRejected(String rejected) {
    if (token != rejected) return;
    token = null;
    _expired.add(null);
  }
}

/// The default client for every API service: stamps `Authorization: Bearer`
/// on each request while someone is signed in, so no service ever passes the
/// user's id itself - the server reads identity from the token.
http.Client apiClient() => _AuthorizedClient(http.Client());

class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = ApiSession.token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final response = await _inner.send(request);
    // Only the server's "this token is no good" (RFC 6750) ends the session.
    // Other 401s, such as a wrong current password, are for the screen that
    // made the request.
    if (token != null &&
        response.statusCode == 401 &&
        (response.headers['www-authenticate'] ?? '').contains('invalid_token')) {
      ApiSession.reportRejected(token);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

/// Turns a server-relative upload path (`/uploads/...`) into a URL on the
/// API host. Absolute URLs pass through; null or empty gives null.
String? resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return Uri.parse(ApiConfig.baseUrl).replace(path: path).toString();
}

String get unreachableServerMessage =>
    'Cannot reach the Kubo server at ${ApiConfig.baseUrl}. Check that the '
    'backend is running (`npm run dev` in backend/) and, on a physical phone, '
    'that API_BASE_URL points at the LAN IP of this machine.';

Future<http.Response> sendRequest(
  Future<http.Response> Function() send, {
  Duration timeout = apiTimeout,
}) async {
  try {
    return await send().timeout(timeout);
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
