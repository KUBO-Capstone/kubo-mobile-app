import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/shared/data/api_request.dart';

// Every service relies on apiClient() for identity; if the header stops going
// out, every protected screen shows "Your session has expired".
void main() {
  test('apiClient sends the bearer token', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? seen;
    server.listen((request) {
      seen = request.headers.value('authorization');
      request.response
        ..statusCode = 200
        ..write('{}')
        ..close();
    });
    ApiSession.token = 'abc.def';
    final client = apiClient();
    await client.get(Uri.parse('http://127.0.0.1:${server.port}/x'));
    client.close();
    await server.close(force: true);
    expect(seen, 'Bearer abc.def');
  });
}
