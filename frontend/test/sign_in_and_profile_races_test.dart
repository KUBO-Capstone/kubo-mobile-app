import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/login/screens/login_page.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/login/services/google_auth.dart';
import 'package:frontend/features/profile/providers/profile_page_controller.dart';
import 'package:frontend/features/profile/screens/account_settings_page.dart';
import 'package:frontend/shared/data/session_store.dart';

import 'support/fake_api.dart';

// Answers that arrive out of order: two sign-ins at once, a profile load
// overtaken by a save, and Account settings handing back what it opened with.
void main() {
  setUp(() => AuthService.store = MemorySessionStore());
  tearDown(() async => AuthService.logout());

  Map<String, dynamic> account(int id, String email) =>
      <String, dynamic>{'user_id': id, 'first_name': 'User', 'last_name': '$id', 'email': email};

  // A request takes a few turns of the event loop to reach the fake server.
  Future<void> untilReached(List<Completer<Object?>> answers, int count) async {
    while (answers.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('two sign-ins at once', () {
    test('the one that finishes first keeps its session; the late one commits nothing', () async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'POST /auth/login': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        final slow = AuthService();
        final fast = AuthService();
        final slowLogin = slow.login(email: 'slow@kubo.local', password: 'password123');
        await untilReached(answers, 1);
        final fastLogin = fast.login(email: 'fast@kubo.local', password: 'password123');
        await untilReached(answers, 2);

        answers[1].complete({...account(2, 'fast@kubo.local'), 'token': 'fast.token'});
        await fastLogin;
        expect(AuthService.currentUserId, 2);

        answers[0].complete({...account(1, 'slow@kubo.local'), 'token': 'slow.token'});
        await expectLater(slowLogin, throwsA(isA<SignInSuperseded>()));
        expect(AuthService.currentUserId, 2, reason: 'the session that won is kept');
        expect(AuthService.accessToken, 'fast.token');
        slow.dispose();
        fast.dispose();
      });
    });

    test('a sign-in started after the last one finished goes through as usual', () async {
      var next = 0;
      final api = FakeApi({
        'POST /auth/login': (_) {
          next++;
          return {...account(next, 'u$next@kubo.local'), 'token': 'token.$next'};
        },
      });
      await api.run(() async {
        final service = AuthService();
        await service.login(email: 'u1@kubo.local', password: 'password123');
        await AuthService.logout();
        await service.login(email: 'u2@kubo.local', password: 'password123');
        expect(AuthService.currentUserId, 2);
        service.dispose();
      });
    });
  });

  group('own profile loads', () {
    setUp(() => AuthService.currentUser = {...account(7, 'juan@gmail.com'), 'contact_number': '', 'preferred_address_id': null});

    test('a load answering after a save does not put the old details back', () async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /users/7/profile': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: true);
        final load = controller.loadProfile();
        await untilReached(answers, 1);

        // Edit Profile saves while the load is away.
        await controller.setProfile({...account(7, 'juan@gmail.com'), 'contact_number': '09171234567', 'preferred_address_id': 12});

        // The load answers with the profile as it was before the save.
        answers[0].complete({...account(7, 'juan@gmail.com'), 'contact_number': '', 'preferred_address_id': null});
        await load;

        expect(controller.loadedProfile?['contact_number'], '09171234567');
        expect(AuthService.currentUser?['contact_number'], '09171234567');
        expect(AuthService.missingProfileDetails, isEmpty, reason: 'still allowed to make offers');
        controller.dispose();
      });
    });

    test('of two loads, the older answer arriving last is dropped', () async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /users/7/profile': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: true);
        final older = controller.loadProfile();
        await untilReached(answers, 1);
        final newer = controller.loadProfile();
        await untilReached(answers, 2);

        answers[1].complete({...account(7, 'juan@gmail.com'), 'bio': 'newer'});
        await newer;
        answers[0].complete({...account(7, 'juan@gmail.com'), 'bio': 'older'});
        await older;

        expect(controller.loadedProfile?['bio'], 'newer');
        controller.dispose();
      });
    });
  });

  group('platforms', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Google sign-in is offered on Android and iOS only', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          GoogleAuth.isSupported,
          platform == TargetPlatform.android || platform == TargetPlatform.iOS,
          reason: '$platform',
        );
      }
    });

    testWidgets('the login page has no Google button on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Email'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    test('on macOS sign-in refuses before reaching Google', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await expectLater(
        GoogleAuth.signInForIdToken(),
        throwsA(predicate((error) => error.toString().contains('not available on this device'))),
      );
    });
  });

  testWidgets('Account settings hands back the signed-in user as it is now', (tester) async {
    final opened = {...account(7, 'juan@gmail.com'), 'profile_photo_url': 'old.jpg'};
    AuthService.currentUser = Map<String, dynamic>.of(opened);
    Map<String, dynamic>? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.of(context).push<Map<String, dynamic>>(
              MaterialPageRoute(builder: (_) => AccountSettingsPage(user: opened, onLogout: () async {})),
            );
          },
          child: const Text('Open settings'),
        ),
      ),
    ));
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    // A session refresh lands while the page is open.
    AuthService.updateCurrentUser({'profile_photo_url': 'new.jpg'});

    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(result?['profile_photo_url'], 'new.jpg');
  });
}
