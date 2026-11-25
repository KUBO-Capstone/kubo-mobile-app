import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A 1x1 transparent PNG, served for anything that is not an API call (map
/// tiles, photos) so widgets that draw network images have something to draw.
final Uint8List transparentPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// What one API route answers with: the `data` of a 200, or a full response.
/// A route may return a future to hold its answer back until a test lets go.
typedef FakeRoute = FutureOr<Object?> Function(http.Request request);

/// An in-memory stand-in for the Kubo API, for `http.runWithClient`.
///
/// [routes] maps `'GET /products/suggestions'` (the path after `/api`) to
/// the `data` to answer with. Unlisted API routes answer 404 the way the
/// server would; everything else gets [transparentPixel]. [requests] records
/// what was asked, in order.
class FakeApi {
  FakeApi([Map<String, FakeRoute>? routes]) : routes = routes ?? <String, FakeRoute>{};

  final Map<String, FakeRoute> routes;
  final List<http.Request> requests = <http.Request>[];

  http.Client get client => MockClient(_handle);

  /// Runs [body] with every `http.Client()` it creates answered from here.
  Future<T> run<T>(Future<T> Function() body) => http.runWithClient(body, () => client);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    if (!path.startsWith('/api/')) {
      return http.Response.bytes(transparentPixel, 200, headers: {'content-type': 'image/png'});
    }
    requests.add(request);
    final route = routes['${request.method} ${path.substring('/api'.length)}'];
    if (route == null) {
      return _json(404, {'success': false, 'message': 'Not found'});
    }
    final answer = await route(request);
    if (answer is http.Response) return answer;
    return _json(200, {'success': true, 'data': answer});
  }

  static http.Response _json(int status, Object body, {Map<String, String> headers = const {}}) {
    return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});
  }

  /// A 401 the way `requireAuth` sends it for a token it no longer accepts.
  static http.Response sessionExpired() => _json(
        401,
        {'success': false, 'message': 'Your session has expired. Please log in again.'},
        headers: {'www-authenticate': 'Bearer error="invalid_token"'},
      );

  /// A refusal with the server's `message`, for any other status.
  static http.Response refused(int status, String message) =>
      _json(status, {'success': false, 'message': message});
}
