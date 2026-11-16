import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the app keeps between launches so the user stays signed in: the
/// bearer token and the user row it belongs to (shown at once on the next
/// launch, then refreshed from the server).
class SavedSession {
  const SavedSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

/// Where the session is kept. `AuthService.store` is the one in use; tests
/// swap in a [MemorySessionStore].
abstract class SessionStore {
  /// The saved session, or null when nobody is signed in on this device.
  Future<SavedSession?> read();

  Future<void> write(SavedSession session);

  Future<void> clear();
}

/// Keeps the session in the platform's protected storage (Android Keystore,
/// iOS Keychain) rather than a plain preferences file, since the token is
/// as good as the password for as long as it lives.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore();

  static const _key = 'kubo.session';

  static const _storage = FlutterSecureStorage(
    // Readable after the first unlock, and never copied to another device.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  @override
  Future<SavedSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['token'];
      final user = decoded['user'];
      if (token is! String || token.isEmpty || user is! Map) return null;
      return SavedSession(token: token, user: Map<String, dynamic>.from(user));
    } on FormatException {
      // Not something this app wrote; treat the device as signed out.
      return null;
    }
  }

  @override
  Future<void> write(SavedSession session) {
    return _storage.write(
      key: _key,
      value: jsonEncode({'token': session.token, 'user': session.user}),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Session kept only for the life of the process.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.session]);

  SavedSession? session;

  @override
  Future<SavedSession?> read() async => session;

  @override
  Future<void> write(SavedSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}
