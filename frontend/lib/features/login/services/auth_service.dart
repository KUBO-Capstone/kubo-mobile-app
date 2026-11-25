import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../../../shared/data/api_request.dart';
import '../../../shared/data/chat_socket.dart';
import '../../../shared/data/session_store.dart';
import 'google_auth.dart';

export 'google_auth.dart' show GoogleSignInCancelled;

/// Another sign-in finished first while this one was under way, and its
/// session is the one kept. Nothing to show: that sign-in has already moved
/// the app on.
class SignInSuperseded implements Exception {
  const SignInSuperseded();

  @override
  String toString() => 'Another sign-in finished first.';
}

/// HTTP client for the backend account and login endpoints, and the keeper
/// of the signed-in session.
///
/// The session (token and user row) is held in memory for the running app
/// and saved in [store], so closing and reopening the app keeps the user
/// signed in: `main` calls [restoreSession] before the first frame, and
/// [refreshSession] then swaps the saved copy for the server's current one.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;

  final http.Client _client;

  /// Where the session is kept between launches. Tests replace it with a
  /// `MemorySessionStore`.
  static SessionStore store = const SecureSessionStore();

  /// How long a session is trusted before [refreshSessionIfStale] asks the
  /// server again. The server's token lives a week and each refresh starts a
  /// new one, so someone who opens the app now and then is never signed out.
  static const Duration refreshAfter = Duration(hours: 12);

  static final ValueNotifier<Map<String, dynamic>?> _currentUser = ValueNotifier<Map<String, dynamic>?>(null);

  static DateTime? _refreshedAt;
  static bool _isRefreshing = false;

  /// Goes up each time a sign-in (email, Google or a new registration)
  /// commits its session.
  static int _signInCommits = 0;

  /// The signed-in user's row, or null when nobody is logged in.
  static Map<String, dynamic>? get currentUser => _currentUser.value;
  static set currentUser(Map<String, dynamic>? user) => _currentUser.value = user;

  /// Notifies on login, logout and profile edits (the Profile tab shows the
  /// user's photo).
  static ValueListenable<Map<String, dynamic>?> get currentUserListenable => _currentUser;

  static String? get accessToken => ApiSession.token;

  /// Numeric id of the signed-in user, or null when nobody is logged in.
  static int? get currentUserId =>
      int.tryParse(currentUser?['user_id']?.toString() ?? '');

  /// What the signed-in account still lacks before it can make an offer or
  /// list produce: email sign-up asks for both, an account made with Google
  /// starts without them. Empty when nothing is missing, and when nobody is
  /// signed in (screens handle that case themselves).
  static List<String> get missingProfileDetails {
    final user = currentUser;
    if (user == null) return const <String>[];
    return <String>[
      if ((user['contact_number']?.toString().trim() ?? '').isEmpty) 'contact number',
      if (user['preferred_address_id'] == null) 'address',
    ];
  }

  static void updateCurrentUser(Map<String, dynamic> user) {
    currentUser = {
      ...?currentUser,
      ...user,
    };
    _save();
  }

  /// Ends the session on this device: in memory at once, then in [store], so
  /// the next launch opens on the login screen. Callers also clear any
  /// per-user caches (saved listings) and rebuild the navigator so nothing
  /// from the old account stays mounted.
  static Future<void> logout() async {
    // Everything up to the first await happens at once, so callers that do
    // not wait are signed out in memory straight away.
    currentUser = null;
    ApiSession.token = null;
    _refreshedAt = null;
    _isRefreshing = false;
    ChatSocket.disconnect();
    // Not waited for, and harmless for an email account: the next "Continue
    // with Google" shows the account picker instead of reusing this account.
    unawaited(GoogleAuth.signOut());
    try {
      await store.clear();
    } catch (error) {
      debugPrint('Could not clear the saved session: $error');
    }
  }

  /// Brings back the session saved by an earlier launch, if there is one.
  /// Returns whether someone is now signed in. Never throws: storage that
  /// cannot be read just means starting signed out.
  static Future<bool> restoreSession() async {
    try {
      final saved = await store.read().timeout(const Duration(seconds: 3));
      if (saved == null) return false;
      ApiSession.token = saved.token;
      currentUser = saved.user;
      ChatSocket.connect(saved.token);
      return true;
    } catch (error) {
      debugPrint('Could not restore the saved session: $error');
      return false;
    }
  }

  /// Checks the session with the server and takes its current user row and a
  /// fresh token. A token the server no longer accepts ends the session
  /// through [ApiSession.expired]; being offline changes nothing, and the
  /// saved session stays in use.
  static Future<void> refreshSession() async {
    final token = ApiSession.token;
    // One check at a time; a second caller has nothing to add.
    if (token == null || _isRefreshing) return;
    _isRefreshing = true;
    final service = AuthService();
    try {
      final response = await sendRequest(() => service._client.get(Uri.parse('${service._baseUrl}/auth/me')));
      // Signed out, or signed in as someone else, while this was in flight.
      if (ApiSession.token != token) return;
      _startSession(readData(response) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Session refresh skipped: $error');
    } finally {
      _isRefreshing = false;
      service.dispose();
    }
  }

  /// [refreshSession], unless the session was checked within [refreshAfter].
  /// Called when the app comes back to the foreground.
  static Future<void> refreshSessionIfStale() async {
    final last = _refreshedAt;
    if (ApiSession.token == null) return;
    if (last != null && DateTime.now().difference(last) < refreshAfter) return;
    await refreshSession();
  }

  // Saves the session as it is now. Not waited for: the app carries on with
  // the copy in memory, and a failed save only costs a login next launch.
  // The store carries out its calls in the order they are made, so a save
  // can never land after the logout that follows it; a save after logout is
  // skipped.
  static void _save() {
    final token = ApiSession.token;
    final user = currentUser;
    if (token == null || user == null) return;
    Future<void>.sync(() => store.write(SavedSession(token: token, user: user))).catchError((Object error) {
      debugPrint('Could not save the session: $error');
    });
  }

  /// Login, register and the session check all answer with the user row plus
  /// a `token`; the token goes to [ApiSession] and the rest becomes
  /// [currentUser]. Fields the row does not carry (the profile's addresses)
  /// are kept from what was already known about the same user.
  static Map<String, dynamic> _startSession(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.of(data);
    final token = user.remove('token') as String?;
    final previous = currentUser;
    final sameUser = previous != null && previous['user_id']?.toString() == user['user_id']?.toString();
    ApiSession.token = token;
    currentUser = sameUser ? {...previous, ...user} : user;
    _refreshedAt = DateTime.now();
    if (token != null) ChatSocket.connect(token);
    _save();
    return user;
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String contactNumber,
    required String region,
    required String province,
    required String cityMunicipality,
    required String zipCode,
  }) {
    // Same rule as the sign-ins below. If another sign-in finished first,
    // the new account still exists and can be logged into later; it just
    // does not replace the session that won.
    return _signIn(() => _post('/auth/register', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'contact_number': contactNumber,
      'region': region,
      'province': province,
      'city_municipality': cityMunicipality,
      'zip_code': zipCode,
    }));
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _signIn(() => _post('/auth/login', {
      'email': email,
      'password': password,
    }));
  }

  /// Signs in with the Google account the user picks. The server checks
  /// Google's ID token and answers like [login]: an existing account (found
  /// by its Google link, or by a verified matching email) or a new one.
  /// Throws [GoogleSignInCancelled] when the user backs out of the picker.
  Future<Map<String, dynamic>> loginWithGoogle() {
    return _signIn(() async {
      final idToken = await GoogleAuth.signInForIdToken();
      return _post('/auth/google', {'id_token': idToken});
    });
  }

  // The rule both sign-ins follow: the first to finish keeps its session.
  // Google's picker and the server can take a while, and the email login
  // stays usable meanwhile, so an older sign-in that lands after a newer one
  // committed throws SignInSuperseded instead of replacing that session.
  Future<Map<String, dynamic>> _signIn(Future<http.Response> Function() request) async {
    final commitsAtStart = _signInCommits;
    final data = readData(await request()) as Map<String, dynamic>;
    if (_signInCommits != commitsAtStart) throw const SignInSuperseded();
    _signInCommits++;
    return _startSession(data);
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
