import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/profile/providers/profile_page_controller.dart';
import 'package:frontend/features/profile/screens/profile_page.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/session_store.dart';

import 'support/fake_api.dart';

// The profile shows what the account has, and nothing made up: follow
// counts from the server, a bio only when one was written.
void main() {
  const me = <String, dynamic>{'user_id': 7, 'first_name': 'Leonard', 'last_name': 'Cruz', 'email': 'leonard@kubo.local'};

  Map<String, dynamic> sellerProfile({String bio = '', int followers = 0, int following = 0, bool isFollowing = false}) => {
        'user_id': 99,
        'first_name': 'Maria',
        'last_name': 'Santos',
        'email': 'maria@kubo.local',
        'bio': bio,
        'location': 'Los Baños',
        'created_at': '2026-03-14T02:00:00.000Z',
        'followers_count': followers,
        'following_count': following,
        'is_following': isFollowing,
      };

  /// The Following / Followers / Listings numbers in the header, in order.
  List<String> headerCounts(WidgetTester tester) {
    return ['Following', 'Followers', 'Listings'].map((label) {
      final column = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
      return tester.widget<Text>(find.descendant(of: column, matching: find.byType(Text)).first).data!;
    }).toList();
  }

  Future<void> openAbout(WidgetTester tester) async {
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    AuthService.store = MemorySessionStore();
    AuthService.currentUser = Map<String, dynamic>.of(me);
    ApiSession.token = 'test.token';
  });

  tearDown(() async {
    await AuthService.logout();
  });

  group('ProfilePageController.profile', () {
    test('before anything loads, a visited profile has no sample bio, date or counts', () {
      final controller = ProfilePageController(
        isOwnProfile: false,
        subject: const ProfileSubject(userId: 99, displayName: 'Maria Santos', locationLabel: 'Los Baños'),
      );
      final profile = controller.profile;

      expect(profile.displayName, 'Maria Santos');
      expect(profile.about, isEmpty);
      expect(profile.joinedLabel, isEmpty);
      expect(profile.username, isEmpty);
      expect(profile.locationLabel, 'Los Baños');
      expect(profile.followersCount, 0);
      expect(profile.followingCount, 0);
      controller.dispose();
    });

    test('an own profile with nothing filled in is empty, not padded', () {
      final controller = ProfilePageController(isOwnProfile: true);
      final profile = controller.profile;

      expect(profile.displayName, 'Leonard Cruz');
      expect(profile.username, 'leonard@kubo.local');
      expect(profile.about, isEmpty);
      expect(profile.locationLabel, isEmpty);
      expect(profile.followersCount, 0);
      expect(profile.followingCount, 0);
      controller.dispose();
    });

    test('counts, bio and join date come from the loaded profile', () async {
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(bio: 'Third-generation rice farmer.', followers: 12, following: 3),
      });
      late ProfilePageController controller;
      await api.run(() async {
        controller = ProfilePageController(
          isOwnProfile: false,
          subject: const ProfileSubject(userId: 99, displayName: 'Maria Santos'),
        );
        await controller.loadProfile();
      });
      final profile = controller.profile;

      expect(profile.followersCount, 12);
      expect(profile.followingCount, 3);
      expect(profile.about, 'Third-generation rice farmer.');
      expect(profile.joinedLabel, matches(RegExp(r'^03/1[34]/2026$')));
      controller.dispose();
    });

    test('an edit answer without counts does not reset them', () async {
      final api = FakeApi({
        'GET /users/7/profile': (_) => {...me, 'followers_count': 5, 'following_count': 2, 'is_following': false},
      });
      late ProfilePageController controller;
      await api.run(() async {
        controller = ProfilePageController(isOwnProfile: true);
        await controller.loadProfile();
      });

      // What the photo upload answers with: the user row, no counts.
      await controller.setProfile({...me, 'profile_photo_url': 'https://example.test/p.jpg'});

      expect(controller.profile.followersCount, 5);
      expect(controller.profile.followingCount, 2);
      expect(controller.profile.photoUrl, 'https://example.test/p.jpg');
      controller.dispose();
    });

    test('following updates the button and count at once, and takes the server count', () async {
      var followers = 12;
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(followers: followers),
        'POST /users/99/follow': (_) => {'followers_count': followers += 1, 'following_count': 0, 'is_following': true},
        'DELETE /users/99/follow': (_) => {'followers_count': followers -= 1, 'following_count': 0, 'is_following': false},
      });
      await api.run(() async {
        final controller = ProfilePageController(
          isOwnProfile: false,
          subject: const ProfileSubject(userId: 99, displayName: 'Maria Santos'),
        );
        await controller.loadProfile();
        expect(controller.isFollowing, isFalse);

        final pending = controller.toggleFollow();
        expect(controller.isFollowing, isTrue, reason: 'changes before the server answers');
        expect(controller.profile.followersCount, 13);
        expect(await pending, isNull);
        expect(controller.profile.followersCount, 13);

        expect(await controller.toggleFollow(), isNull);
        expect(controller.isFollowing, isFalse);
        expect(controller.profile.followersCount, 12);
        controller.dispose();
      });
      expect(api.requests.map((r) => '${r.method} ${r.url.path}').where((r) => r.contains('follow')),
          ['POST /api/users/99/follow', 'DELETE /api/users/99/follow']);
    });

    test('a refused follow puts the button and count back and says why', () async {
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(followers: 12),
        'POST /users/99/follow': (_) => FakeApi.refused(404, 'User not found'),
      });
      await api.run(() async {
        final controller = ProfilePageController(
          isOwnProfile: false,
          subject: const ProfileSubject(userId: 99, displayName: 'Maria Santos'),
        );
        await controller.loadProfile();

        expect(await controller.toggleFollow(), 'User not found');
        expect(controller.isFollowing, isFalse);
        expect(controller.profile.followersCount, 12);
        controller.dispose();
      });
    });

    test('following needs a signed-in user', () async {
      await AuthService.logout();
      final controller = ProfilePageController(
        isOwnProfile: false,
        subject: const ProfileSubject(userId: 99, displayName: 'Maria Santos'),
      );

      expect(await controller.toggleFollow(), 'Log in to follow sellers.');
      controller.dispose();
    });
  });

  group('the profile page', () {
    testWidgets('header counts are the account\'s own, not sample numbers', (tester) async {
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(followers: 12, following: 3),
      });
      await api.run(() async {
        await tester.pumpWidget(MaterialApp(home: ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')));
        await tester.pumpAndSettle();
      });

      expect(headerCounts(tester), ['3', '12', '0']);
    });

    testWidgets('with no server the counts read zero rather than 33 and 20', (tester) async {
      await FakeApi().run(() async {
        await tester.pumpWidget(MaterialApp(home: ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')));
        await tester.pumpAndSettle();
      });

      expect(headerCounts(tester), ['0', '0', '0']);
    });

    testWidgets('Follow becomes Following and the follower count goes up', (tester) async {
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(followers: 12),
        'POST /users/99/follow': (_) => {'followers_count': 13, 'following_count': 0, 'is_following': true},
      });
      await api.run(() async {
        await tester.pumpWidget(MaterialApp(home: ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, 'Follow'), findsOneWidget);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Follow'));
        await tester.pumpAndSettle();
      });

      expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Follow'), findsNothing);
      expect(headerCounts(tester)[1], '13');
      expect(find.text('Followed profile'), findsNothing);
    });

    testWidgets('About shows the written bio and the real join date', (tester) async {
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(bio: 'Third-generation rice farmer.', followers: 12),
      });
      await api.run(() async {
        await tester.pumpWidget(MaterialApp(home: ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')));
        await tester.pumpAndSettle();
        await openAbout(tester);
      });

      expect(find.text('Third-generation rice farmer.'), findsOneWidget);
      expect(find.textContaining('Date Joined | 03/1'), findsOneWidget);
      expect(find.textContaining('June 2025'), findsNothing);
      // The Followers card in Profile analytics agrees with the header.
      expect(find.text('12'), findsNWidgets(2));
    });

    testWidgets('About says there is no bio instead of showing sample text', (tester) async {
      final api = FakeApi({'GET /users/99/profile': (_) => sellerProfile()});
      await api.run(() async {
        await tester.pumpWidget(MaterialApp(home: ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')));
        await tester.pumpAndSettle();
        await openAbout(tester);
      });

      expect(find.text('No bio yet.'), findsOneWidget);
      expect(find.textContaining("don't call me baby"), findsNothing);
      expect(find.textContaining('Fresh local produce from a Kubo grower'), findsNothing);
      expect(find.text('Add a Bio'), findsNothing, reason: 'only on your own profile');
    });

    testWidgets('your own About offers to add a bio, and has no Log out button', (tester) async {
      final api = FakeApi({
        'GET /users/7/profile': (_) => {...me, 'bio': '', 'followers_count': 4, 'following_count': 1, 'is_following': false},
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();
        await openAbout(tester);
      });

      expect(find.textContaining('You have not written a bio yet'), findsOneWidget);
      expect(find.text('Add a Bio'), findsOneWidget);
      expect(find.text('Log Out'), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
      expect(headerCounts(tester), ['1', '4', '0']);
      // Rows the account has nothing for are left out rather than filled in.
      expect(find.textContaining('Caloocan'), findsNothing);
      expect(find.text('leonard@kubo.local'), findsNWidgets(2));
    });
  });
}
