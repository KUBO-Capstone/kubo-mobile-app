import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/explore/widgets/listings_map.dart';
import 'package:frontend/features/listing/providers/listing_page_controller.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/profile/providers/profile_page_controller.dart';
import 'package:frontend/features/search/providers/search_page_controller.dart';
import 'package:frontend/features/search/screens/search_results_page.dart';
import 'package:frontend/features/shell/providers/app_shell_controller.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/listing_service.dart';
import 'package:frontend/shared/data/session_store.dart';
import 'package:frontend/shared/data/synthetic_records.dart';
import 'package:frontend/shared/widgets/kubo_listing_card.dart';

import 'support/fake_api.dart';

// Answers can come back in a different order than they were asked for, and
// the same listings can come back changed. What is on screen must follow the
// newest state, not the last answer to arrive.

Map<String, dynamic> _listingJson(int id, {String name = 'Sitaw', num quantity = 10, double? lat, double? lng}) => {
      'product_id': id,
      'seller_id': 1,
      'crop_name': name,
      'base_price': 100,
      'unit_measurement': 'kg',
      'available_quantity': quantity,
      'status': 'available',
      'seller_name': 'Selma Tester',
      'location_label': 'BAGUIO CITY',
      'region_label': 'CAR',
      'latitude': lat,
      'longitude': lng,
      'images': <String>[],
    };

SyntheticListingRecord _listing(int id, {String name = 'Sitaw', num quantity = 10, double? lat, double? lng}) =>
    SyntheticListingRecord.fromJson(_listingJson(id, name: name, quantity: quantity, lat: lat, lng: lng));

/// A listing service whose answers a test releases by hand, in any order.
class _GatedListings extends ListingService {
  final List<Completer<SyntheticListingRecord>> listingAnswers = [];
  final List<Completer<List<ListingSuggestion>>> suggestionAnswers = [];

  @override
  Future<SyntheticListingRecord> fetchListing(int productId) {
    listingAnswers.add(Completer<SyntheticListingRecord>());
    return listingAnswers.last.future;
  }

  @override
  Future<List<ListingSuggestion>> fetchSuggestions({String query = '', int? limit}) {
    suggestionAnswers.add(Completer<List<ListingSuggestion>>());
    return suggestionAnswers.last.future;
  }
}

void main() {
  group('CallLine (session storage)', () {
    test('a slow save cannot land after the clear that followed it', () async {
      final line = CallLine();
      String? stored;
      final save = line.add(() async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        stored = 'session';
      });
      final clear = line.add(() async => stored = null);

      await Future.wait([save, clear]);

      expect(stored, isNull);
    });

    test('calls run in the order they were added', () async {
      final line = CallLine();
      final order = <int>[];
      final calls = [
        for (final (index, wait) in [30, 0, 10].indexed)
          line.add(() async {
            await Future<void>.delayed(Duration(milliseconds: wait));
            order.add(index);
          }),
      ];

      await Future.wait(calls);

      expect(order, [0, 1, 2]);
    });

    test('a failed call reaches its caller and does not hold up the next', () async {
      final line = CallLine();
      final failed = line.add<void>(() async => throw StateError('keystore unavailable'));
      final next = line.add(() async => 'done');

      await expectLater(failed, throwsStateError);
      expect(await next, 'done');
    });
  });

  group('ListingPageController', () {
    test('a refresh that started before an edit does not put the old listing back', () async {
      final listings = _GatedListings();
      final controller = ListingPageController(listing: _listing(1, quantity: 10), listings: listings);

      final refresh = controller.refresh();
      // The seller saves an edit while the refresh is still in flight.
      controller.replaceListing(_listing(1, name: 'Sitaw (edited)', quantity: 25));
      listings.listingAnswers.single.complete(_listing(1, quantity: 10));
      await refresh;

      expect(controller.listing.title, 'Sitaw (edited)');
      expect(controller.listing.availableQuantity, 25);
      controller.dispose();
    });

    test('of two refreshes, the later one wins whichever answers first', () async {
      final listings = _GatedListings();
      final controller = ListingPageController(listing: _listing(1, quantity: 10), listings: listings);

      final first = controller.refresh();
      final second = controller.refresh();
      listings.listingAnswers[1].complete(_listing(1, quantity: 6));
      await second;
      listings.listingAnswers[0].complete(_listing(1, quantity: 10));
      await first;

      expect(controller.listing.availableQuantity, 6);
      controller.dispose();
    });

    test('a refresh with nothing newer still updates the listing', () async {
      final listings = _GatedListings();
      final controller = ListingPageController(listing: _listing(1, quantity: 10), listings: listings);

      final refresh = controller.refresh();
      listings.listingAnswers.single.complete(_listing(1, quantity: 7));
      await refresh;

      expect(controller.listing.availableQuantity, 7);
      controller.dispose();
    });
  });

  group('SearchPageController.loadPopular', () {
    const older = [ListingSuggestion(text: 'Older', type: SuggestionType.listing)];
    const newer = [ListingSuggestion(text: 'Newer', type: SuggestionType.listing)];

    test('an older answer arriving last does not replace the newer one', () async {
      final listings = _GatedListings();
      final controller = SearchPageController(service: listings);

      final first = controller.loadPopular();
      final second = controller.loadPopular();
      listings.suggestionAnswers[1].complete(newer);
      await second;
      listings.suggestionAnswers[0].complete(older);
      await first;

      expect(controller.popular.single.text, 'Newer');
      expect(controller.isLoadingPopular, isFalse);
      controller.dispose();
    });

    test('an older failure arriving last does not mark the newer result as failed', () async {
      final listings = _GatedListings();
      final controller = SearchPageController(service: listings);

      final first = controller.loadPopular();
      final second = controller.loadPopular();
      listings.suggestionAnswers[1].complete(const <ListingSuggestion>[]);
      await second;
      listings.suggestionAnswers[0].completeError(Exception('offline'));
      await first;

      expect(controller.popularFailed, isFalse);
      controller.dispose();
    });

    test('loading only ends when the newest request answers', () async {
      final listings = _GatedListings();
      final controller = SearchPageController(service: listings);

      final first = controller.loadPopular();
      final second = controller.loadPopular();
      listings.suggestionAnswers[0].complete(older);
      await first;
      expect(controller.isLoadingPopular, isTrue);
      expect(controller.popular, isEmpty);

      listings.suggestionAnswers[1].complete(newer);
      await second;
      expect(controller.isLoadingPopular, isFalse);
      expect(controller.popular.single.text, 'Newer');
      controller.dispose();
    });
  });

  group('SearchResultsPage', () {
    testWidgets('a slow first answer does not replace the results of a later search for the same words', (tester) async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /products': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchResultsPage(query: 'sitaw')));
        await tester.pump();

        // Search again for the same words before the first answer is back.
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(answers, hasLength(2));

        answers[1].complete([_listingJson(1, name: 'Sitaw fresh')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(KuboListingCard), findsOneWidget);

        // The first request finally answers, with nothing.
        answers[0].complete(<dynamic>[]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(find.byType(KuboListingCard), findsOneWidget);
      expect(find.textContaining('No listings match'), findsNothing);
    });

    testWidgets('a listing change during a search is reloaded once the search is done', (tester) async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /products': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchResultsPage(query: 'sitaw')));
        await tester.pump();
        expect(answers, hasLength(1));

        // Stock moves while the search is still out: nothing new is sent yet.
        AppShellController.instance.notifyListingsChanged();
        AppShellController.instance.notifyListingsChanged();
        await tester.pump();
        expect(answers, hasLength(1));

        // The search answers with what it read before the change...
        answers[0].complete([_listingJson(1, name: 'Sitaw fresh', quantity: 10)]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(KuboListingCard), findsOneWidget);
        // ...and one reload follows, for both changes.
        expect(answers, hasLength(2));

        // The listing sold out in the meantime and drops off.
        answers[1].complete(<dynamic>[]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(answers, hasLength(2));
      expect(find.byType(KuboListingCard), findsNothing);
    });

    testWidgets('the waiting reload runs after a failed search too, and only once', (tester) async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /products': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchResultsPage(query: 'sitaw')));
        await tester.pump();
        AppShellController.instance.notifyListingsChanged();
        await tester.pump();

        answers[0].complete(FakeApi.refused(500, 'Server error'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(answers, hasLength(2));

        answers[1].complete([_listingJson(1, name: 'Sitaw fresh')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(answers, hasLength(2));
      expect(find.byType(KuboListingCard), findsOneWidget);
      expect(find.textContaining('Could not reach the Kubo server'), findsNothing);
    });

    testWidgets('a superseded search does not run the waiting reload; the newest one does', (tester) async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /products': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchResultsPage(query: 'sitaw')));
        await tester.pump();
        AppShellController.instance.notifyListingsChanged();
        await tester.pump();

        // A second search goes out, then the first one answers late.
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
        expect(answers, hasLength(2));
        answers[0].complete([_listingJson(1, name: 'Stale')]);
        await tester.pump();
        expect(answers, hasLength(2), reason: 'the overtaken search leaves the reload to the newest one');

        answers[1].complete([_listingJson(1, name: 'Sitaw fresh')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(answers, hasLength(3));
        answers[2].complete([_listingJson(1, name: 'Sitaw after change')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(find.text('Sitaw after change'), findsOneWidget);
      expect(find.text('Stale'), findsNothing);
    });

    testWidgets('a slow first failure does not wipe the results of a later search', (tester) async {
      final answers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /products': (_) {
          answers.add(Completer<Object?>());
          return answers.last.future;
        },
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchResultsPage(query: 'sitaw')));
        await tester.pump();
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        answers[1].complete([_listingJson(1, name: 'Sitaw fresh')]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        answers[0].complete(FakeApi.refused(500, 'Server error'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(find.byType(KuboListingCard), findsOneWidget);
      expect(find.textContaining('Could not reach the Kubo server'), findsNothing);
    });
  });

  group('ProfilePageController', () {
    const me = <String, dynamic>{'user_id': 7, 'first_name': 'Leonard', 'last_name': 'Cruz', 'email': 'leonard@kubo.local'};
    const maria = ProfileSubject(userId: 99, displayName: 'Maria Santos');

    Map<String, dynamic> sellerProfile({int followers = 12, bool isFollowing = false, Map<String, dynamic> extra = const {}}) => {
          'user_id': 99,
          'first_name': 'Maria',
          'last_name': 'Santos',
          'followers_count': followers,
          'following_count': 3,
          'is_following': isFollowing,
          ...extra,
        };

    setUp(() {
      AuthService.store = MemorySessionStore();
      AuthService.currentUser = Map<String, dynamic>.of(me);
      ApiSession.token = 'test.token';
    });

    tearDown(() async {
      await AuthService.logout();
    });

    test('a profile load that started before a follow does not undo it', () async {
      final profileAnswers = <Completer<Object?>>[];
      final api = FakeApi({
        'GET /users/99/profile': (_) {
          profileAnswers.add(Completer<Object?>());
          return profileAnswers.last.future;
        },
        'POST /users/99/follow': (_) => {'followers_count': 13, 'following_count': 3, 'is_following': true},
      });
      await api.run(() async {
        // A request takes a few turns of the event loop to reach the server.
        Future<void> requestsToReach(int count) async {
          while (profileAnswers.length < count) {
            await Future<void>.delayed(Duration.zero);
          }
        }

        final controller = ProfilePageController(isOwnProfile: false, subject: maria);
        final firstLoad = controller.loadProfile();
        await requestsToReach(1);
        profileAnswers[0].complete(sellerProfile());
        await firstLoad;

        // A reload goes out; the follow starts and finishes while it is away.
        final reload = controller.loadProfile();
        await requestsToReach(2);
        expect(await controller.toggleFollow(), isNull);
        expect(controller.isFollowing, isTrue);

        // The reload answers from before the follow, with a new bio.
        profileAnswers[1].complete(sellerProfile(extra: {'bio': 'Rice farmer.'}));
        await reload;

        expect(controller.isFollowing, isTrue, reason: 'the follow is newer than the answer');
        expect(controller.profile.followersCount, 13);
        expect(controller.profile.about, 'Rice farmer.', reason: 'the rest of the answer is still taken');
        controller.dispose();
      });
    });

    test('a profile load that lands while a follow is in flight keeps the button as tapped', () async {
      final followAnswer = Completer<Object?>();
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(),
        'POST /users/99/follow': (_) => followAnswer.future,
      });
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: false, subject: maria);
        await controller.loadProfile();

        final follow = controller.toggleFollow();
        await controller.loadProfile();
        expect(controller.isFollowing, isTrue);
        expect(controller.profile.followersCount, 13);

        followAnswer.complete({'followers_count': 13, 'following_count': 3, 'is_following': true});
        expect(await follow, isNull);
        expect(controller.isFollowing, isTrue);
        controller.dispose();
      });
    });

    test('an ordinary reload still takes the server\'s follow state', () async {
      var following = false;
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(followers: following ? 13 : 12, isFollowing: following),
      });
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: false, subject: maria);
        await controller.loadProfile();
        expect(controller.isFollowing, isFalse);

        // Followed from another device.
        following = true;
        await controller.loadProfile();
        expect(controller.isFollowing, isTrue);
        expect(controller.profile.followersCount, 13);
        controller.dispose();
      });
    });

    test('a refused follow puts back only what it changed', () async {
      final followAnswer = Completer<Object?>();
      var bio = '';
      final api = FakeApi({
        'GET /users/99/profile': (_) => sellerProfile(extra: {'bio': bio}),
        'POST /users/99/follow': (_) => followAnswer.future,
      });
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: false, subject: maria);
        await controller.loadProfile();

        final follow = controller.toggleFollow();
        bio = 'Rice farmer.';
        await controller.loadProfile();
        followAnswer.complete(FakeApi.refused(404, 'User not found'));

        expect(await follow, 'User not found');
        expect(controller.isFollowing, isFalse);
        expect(controller.profile.followersCount, 12);
        expect(controller.profile.about, 'Rice farmer.', reason: 'what loaded meanwhile is kept');
        controller.dispose();
      });
    });

    test('your own follow counts stay visible when the profile cannot be fetched', () async {
      // What the last successful load left in the saved session.
      AuthService.currentUser = {...me, 'followers_count': 4, 'following_count': 2};
      final api = FakeApi({'GET /users/7/profile': (_) => FakeApi.refused(503, 'Service unavailable')});
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: true);
        await controller.loadProfile();

        expect(controller.profile.followersCount, 4);
        expect(controller.profile.followingCount, 2);
        controller.dispose();
      });
    });

    test('a visited profile that hides its location shows none, even if addresses came along', () async {
      Map<String, dynamic> withAddress(bool showLocation) => sellerProfile(extra: {
            'location': 'Los Baños',
            'preferred_address_id': 5,
            'addresses': [
              {'address_id': 5, 'region': 'REGION IV-A', 'province': 'LAGUNA', 'city_municipality': 'LOS BAÑOS'},
            ],
            'profile_privacy': {'public_profile': true, 'show_bio': true, 'show_contact_number': true, 'show_location': showLocation},
          });
      var showLocation = false;
      final api = FakeApi({'GET /users/99/profile': (_) => withAddress(showLocation)});
      await api.run(() async {
        final controller = ProfilePageController(isOwnProfile: false, subject: maria);
        await controller.loadProfile();
        expect(controller.profile.locationLabel, isEmpty);
        expect(controller.loadedProfile!.containsKey('addresses'), isFalse);
        expect(controller.loadedProfile!.containsKey('preferred_address_id'), isFalse);

        // With location shown, the address is used as before.
        showLocation = true;
        await controller.loadProfile();
        expect(controller.profile.locationLabel, 'LOS BAÑOS, LAGUNA');
        controller.dispose();
      });
    });
  });

  group('the explore map', () {
    Future<void> pumpMap(WidgetTester tester, List<SyntheticListingRecord> listings) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListingsMap(listings: listings, minimized: false, onToggleMinimized: () {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    MapCamera camera(WidgetTester tester) => MapCamera.of(tester.element(find.byType(MarkerLayer)));

    testWidgets('moves to a listing when the same listing comes back with a point', (tester) async {
      await FakeApi().run(() async {
        await pumpMap(tester, [_listing(1)]);
        final countryZoom = camera(tester).zoom;
        expect(find.textContaining('not on the map yet'), findsOneWidget);

        // The refresh after the town lookup: same id, now with coordinates.
        await pumpMap(tester, [_listing(1, lat: 16.41, lng: 120.59)]);

        expect(camera(tester).center.latitude, closeTo(16.41, 0.001));
        expect(camera(tester).center.longitude, closeTo(120.59, 0.001));
        expect(camera(tester).zoom, greaterThan(countryZoom));
        expect(find.textContaining('not on the map yet'), findsNothing);
      });
    });

    testWidgets('follows a listing whose point changes', (tester) async {
      await FakeApi().run(() async {
        await pumpMap(tester, [_listing(1, lat: 16.41, lng: 120.59)]);
        await pumpMap(tester, [_listing(1, lat: 14.55, lng: 121.02)]);

        expect(camera(tester).center.latitude, closeTo(14.55, 0.001));
        expect(camera(tester).center.longitude, closeTo(121.02, 0.001));
      });
    });

    testWidgets('leaves the camera alone when the same listings come back unchanged', (tester) async {
      await FakeApi().run(() async {
        await pumpMap(tester, [_listing(1, lat: 16.41, lng: 120.59)]);
        // The user zooms out and the feed reloads the same data.
        await tester.tap(find.byTooltip('Zoom out'));
        await tester.pumpAndSettle();
        final zoomed = camera(tester).zoom;

        await pumpMap(tester, [_listing(1, quantity: 4, lat: 16.41, lng: 120.59)]);

        expect(camera(tester).zoom, zoomed);
      });
    });
  });

  group('map zoom buttons', () {
    testWidgets('repeated taps each land exactly one level on', (tester) async {
      await FakeApi().run(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ListingsMap(
                  listings: [_listing(1, lat: 16.41, lng: 120.59)],
                  minimized: false,
                  onToggleMinimized: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final start = MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom;

        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(find.byTooltip('Zoom in'));
          await tester.pumpAndSettle();
        }
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(find.byTooltip('Zoom out'));
          await tester.pumpAndSettle();
        }

        // Still exact after repeated taps: each glide ends where it aimed.
        expect(MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom, closeTo(start, 0.001));
      });
    });
  });
}
