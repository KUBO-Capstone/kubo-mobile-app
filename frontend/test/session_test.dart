import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/constants/api_config.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/session_store.dart';
import 'package:frontend/shared/widgets/kubo_bottom_navigation_bar.dart';

import 'support/fake_api.dart';

// Staying signed in between launches: what is saved, what brings it back,
// and what ends it.
void main() {
  late MemorySessionStore store;

  const savedUser = <String, dynamic>{'user_id': 7, 'first_name': 'Leonard', 'last_name': 'Cruz', 'email': 'leonard@kubo.local'};

  setUp(() {
    store = MemorySessionStore();
    AuthService.store = store;
  });

  tearDown(() async {
    await AuthService.logout();
  });

  group('the saved session', () {
    test('a launch with nothing saved starts signed out', () async {
      expect(await AuthService.restoreSession(), isFalse);
      expect(AuthService.currentUser, isNull);
      expect(ApiSession.token, isNull);
    });

    test('a launch with a saved session is signed in again', () async {
      store.session = const SavedSession(token: 'saved.token', user: savedUser);

      expect(await AuthService.restoreSession(), isTrue);
      expect(ApiSession.token, 'saved.token');
      expect(AuthService.currentUserId, 7);
      expect(AuthService.currentUser?['first_name'], 'Leonard');
    });

    test('logging in saves the session, and logging out forgets it', () async {
      final api = FakeApi({
        'POST /auth/login': (_) => {...savedUser, 'token': 'fresh.token'},
      });
      await api.run(() async {
        final service = AuthService();
        await service.login(email: 'leonard@kubo.local', password: 'password123');
        service.dispose();
      });
      await Future<void>.delayed(Duration.zero);
      expect(store.session?.token, 'fresh.token');
      expect(store.session?.user['user_id'], 7);
      expect(store.session?.user.containsKey('token'), isFalse, reason: 'the token is kept apart from the user row');

      await AuthService.logout();
      expect(store.session, isNull);
      expect(await AuthService.restoreSession(), isFalse);
    });

    test('a profile edit is saved with the session', () async {
      store.session = const SavedSession(token: 'saved.token', user: savedUser);
      await AuthService.restoreSession();

      AuthService.updateCurrentUser({'first_name': 'Leo', 'bio': 'Grows kamote.'});
      await Future<void>.delayed(Duration.zero);

      expect(store.session?.user['first_name'], 'Leo');
      expect(store.session?.user['bio'], 'Grows kamote.');
      expect(store.session?.token, 'saved.token');
    });

    test('storage that cannot be read just means starting signed out', () async {
      AuthService.store = _BrokenStore();
      expect(await AuthService.restoreSession(), isFalse);
      expect(AuthService.currentUser, isNull);
    });
  });

  group('checking the session with the server', () {
    test('takes the current user row and a fresh token, and saves both', () async {
      store.session = const SavedSession(token: 'saved.token', user: {...savedUser, 'addresses': <dynamic>[]});
      await AuthService.restoreSession();
      final api = FakeApi({
        'GET /auth/me': (_) => {...savedUser, 'first_name': 'Leonardo', 'token': 'rotated.token'},
      });

      await api.run(AuthService.refreshSession);
      await Future<void>.delayed(Duration.zero);

      expect(api.requests.single.headers['Authorization'], 'Bearer saved.token');
      expect(ApiSession.token, 'rotated.token');
      expect(AuthService.currentUser?['first_name'], 'Leonardo');
      expect(AuthService.currentUser?.containsKey('addresses'), isTrue, reason: 'fields the row does not carry are kept');
      expect(store.session?.token, 'rotated.token');
    });

    test('being offline keeps the saved session in use', () async {
      store.session = const SavedSession(token: 'saved.token', user: savedUser);
      await AuthService.restoreSession();
      final api = FakeApi({
        'GET /auth/me': (_) => FakeApi.refused(503, 'Service unavailable'),
      });

      await api.run(AuthService.refreshSession);

      expect(ApiSession.token, 'saved.token');
      expect(AuthService.currentUserId, 7);
      expect(store.session?.token, 'saved.token');
    });

    test('a token the server refuses ends the session once, however many requests fail', () async {
      store.session = const SavedSession(token: 'old.token', user: savedUser);
      await AuthService.restoreSession();
      var expired = 0;
      final subscription = ApiSession.expired.listen((_) => expired += 1);
      final api = FakeApi({
        'GET /auth/me': (_) => FakeApi.sessionExpired(),
        'GET /orders': (_) => FakeApi.sessionExpired(),
      });

      await api.run(() async {
        final client = apiClient();
        await Future.wait([
          AuthService.refreshSession(),
          client.get(Uri.parse('${ApiConfig.baseUrl}/orders')),
          client.get(Uri.parse('${ApiConfig.baseUrl}/orders')),
        ]);
        client.close();
      });
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(expired, 1);
      expect(ApiSession.token, isNull);
    });

    test('a 401 that is not about the token leaves the session alone', () async {
      store.session = const SavedSession(token: 'good.token', user: savedUser);
      await AuthService.restoreSession();
      var expired = 0;
      final subscription = ApiSession.expired.listen((_) => expired += 1);
      final api = FakeApi({
        'PATCH /users/7/password': (_) => FakeApi.refused(401, 'Current password is incorrect'),
      });

      await api.run(() async {
        final client = apiClient();
        final response = await client.patch(Uri.parse('${ApiConfig.baseUrl}/users/7/password'));
        client.close();
        expect(response.statusCode, 401);
      });
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(expired, 0);
      expect(ApiSession.token, 'good.token');
    });

    test('a signed-out request that gets a 401 does not report an expired session', () async {
      var expired = 0;
      final subscription = ApiSession.expired.listen((_) => expired += 1);
      final api = FakeApi({'GET /orders': (_) => FakeApi.sessionExpired()});

      await api.run(() async {
        final client = apiClient();
        await client.get(Uri.parse('${ApiConfig.baseUrl}/orders'));
        client.close();
      });
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(expired, 0);
    });
  });

  group('the app', () {
    testWidgets('opens on the login screen when nobody is signed in', (tester) async {
      await FakeApi().run(() async {
        await tester.pumpWidget(const KuboApp());
        await tester.pumpAndSettle();
      });

      expect(find.text('Continue with Email'), findsOneWidget);
      expect(find.byType(KuboBottomNavigationBar), findsNothing);
    });

    testWidgets('opens straight into the app for a restored session, with no login screen under it', (tester) async {
      AuthService.currentUser = Map<String, dynamic>.of(savedUser);
      final api = FakeApi();

      await api.run(() async {
        await tester.pumpWidget(const KuboApp());
        await tester.pumpAndSettle();
      });

      expect(find.byType(KuboBottomNavigationBar), findsOneWidget);
      expect(find.text('Continue with Email'), findsNothing);
      // Back on Home leaves the app; it must not uncover the login screen.
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    });

    testWidgets('goes back to the login screen when the server refuses the session', (tester) async {
      store.session = const SavedSession(token: 'old.token', user: savedUser);
      ApiSession.token = 'old.token';
      AuthService.currentUser = Map<String, dynamic>.of(savedUser);
      final api = FakeApi({'GET /auth/me': (_) => FakeApi.sessionExpired()});

      await api.run(() async {
        await tester.pumpWidget(const KuboApp());
        await tester.pumpAndSettle();
      });

      expect(find.text('Continue with Email'), findsOneWidget);
      expect(find.byType(KuboBottomNavigationBar), findsNothing);
      expect(find.text('Your session has expired. Please log in again.'), findsOneWidget);
      expect(AuthService.currentUser, isNull);
      expect(store.session, isNull, reason: 'the next launch must not restore it');
    });
  });
}

class _BrokenStore implements SessionStore {
  @override
  Future<SavedSession?> read() => Future<SavedSession?>.error(StateError('keystore unavailable'));

  @override
  Future<void> write(SavedSession session) => Future<void>.error(StateError('keystore unavailable'));

  @override
  Future<void> clear() => Future<void>.error(StateError('keystore unavailable'));
}
