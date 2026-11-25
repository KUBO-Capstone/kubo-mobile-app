// Client IDs for Sign in with Google, supplied at build time:
//   flutter run --dart-define-from-file=dart_defines.json
// (copy dart_defines.example.json; docs/google_sign_in.md says where each
// value comes from). Nothing here is secret, but it differs per Google Cloud
// project, so it stays out of the code.
abstract final class GoogleAuthConfig {
  /// The *Web application* OAuth client ID. Google issues the ID token for
  /// this client, and the backend's GOOGLE_CLIENT_IDS must hold the same
  /// value. Required on Android (Credential Manager refuses without it) and
  /// iOS alike.
  static const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// The *iOS* OAuth client ID. Only iOS uses it; Android finds its client
  /// from the package name and signing certificate instead.
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Whether this build was given what Google sign-in needs.
  static bool get isConfigured => serverClientId.isNotEmpty;
}
