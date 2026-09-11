import 'package:flutter/foundation.dart';

// Single source of truth for the backend base URL used by every API client.
//
// Override the resolved value at launch with:
//   flutter run --dart-define=API_BASE_URL=http://HOST:3000/api
abstract final class ApiConfig {
  /// Value supplied via --dart-define; wins over the per-platform default.
  static const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Host loopback as seen from inside the Android emulator. Plain `localhost`
  /// there resolves to the emulator itself, not the development machine.
  static const _androidEmulatorBaseUrl = 'http://10.0.2.2:3000/api';

  /// Loopback used by desktop, web, and the iOS simulator, which share the host
  /// network namespace. Physical devices need --dart-define with the LAN IP.
  static const _loopbackBaseUrl = 'http://localhost:3000/api';

  /// Base URL every service should use when building request URIs.
  static String get baseUrl {
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }
    final isAndroidDevice =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroidDevice ? _androidEmulatorBaseUrl : _loopbackBaseUrl;
  }
}
