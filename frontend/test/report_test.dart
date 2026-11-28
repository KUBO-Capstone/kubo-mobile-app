import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/listing/screens/listing_page.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/profile/screens/profile_page.dart';
import 'package:frontend/features/report/screens/report_target_page.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/session_store.dart';
import 'package:frontend/shared/data/synthetic_records.dart';

import 'support/fake_api.dart';

// The kebab menu on a listing and a profile (Share, Report), and the Report
// page it leads to.

const _seller = 99;
const _buyer = 7;

const _listing = SyntheticListingRecord(
  id: '12',
  title: 'Calamansi',
  price: 'PHP 80 / kg',
  locationLabel: 'Malolos',
  regionLabel: 'Region III',
  sellerLabel: 'Maria Santos',
  imageAssetPath: 'assets/images/Placeholder_img.png',
  productId: 12,
  sellerId: _seller,
);

void signIn(int userId) => AuthService.currentUser = <String, dynamic>{
      'user_id': userId,
      'contact_number': '09171234567',
      'preferred_address_id': 1,
    };

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More options'));
  await tester.pumpAndSettle();
}

/// Phone-sized, so the page lays out the way it does on a device.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    AuthService.store = MemorySessionStore();
    ApiSession.token = 'test.token';
    signIn(_buyer);
  });
  tearDown(() {
    AuthService.currentUser = null;
    ApiSession.token = null;
  });

  Future<FakeApi> openListing(WidgetTester tester, {SyntheticListingRecord listing = _listing, FakeApi? api}) async {
    final fake = api ?? FakeApi();
    await fake.run(() async {
      await tester.pumpWidget(MaterialApp(home: ListingPage(listing: listing)));
      await tester.pumpAndSettle();
    });
    return fake;
  }

  group('listing page', () {
    testWidgets('the kebab sits right of the heart, and Share has moved into it', (tester) async {
      usePhoneScreen(tester);
      await openListing(tester);

      expect(find.byTooltip('Share listing'), findsNothing);
      final heart = tester.getCenter(find.byTooltip('Save listing'));
      final kebab = tester.getCenter(find.byTooltip('More options'));
      expect(kebab.dx, greaterThan(heart.dx));
      expect(kebab.dy, moreOrLessEquals(heart.dy, epsilon: 1));

      await openMenu(tester);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Report This Listing'), findsOneWidget);
    });

    testWidgets('the seller gets Share but cannot report their own listing', (tester) async {
      signIn(_seller);
      await openListing(tester);
      await openMenu(tester);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Report This Listing'), findsNothing);
    });

    testWidgets('a mock listing with nothing to link to has no kebab', (tester) async {
      await openListing(tester, listing: syntheticExploreListings.first);
      expect(find.byTooltip('More options'), findsNothing);
    });

    testWidgets('logged out, Report asks the user to log in instead', (tester) async {
      AuthService.currentUser = null;
      await openListing(tester);
      await openMenu(tester);
      await tester.tap(find.text('Report This Listing'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportTargetPage), findsNothing);
      expect(find.text('Log in to report a listing.'), findsOneWidget);
    });

    testWidgets('reporting shows the listing, needs a reason, files it and thanks the user', (tester) async {
      usePhoneScreen(tester);
      final api = FakeApi({'POST /reports/listings/12': (_) => {'report_id': 1}});
      await openListing(tester, api: api);
      await openMenu(tester);
      await api.run(() async {
        await tester.tap(find.text('Report This Listing'));
        await tester.pumpAndSettle();
      });

      expect(find.text('REPORT LISTING'), findsOneWidget);
      final page = find.byType(ReportTargetPage);
      expect(find.descendant(of: page, matching: find.text('Calamansi')), findsOneWidget);
      expect(find.text('Sold by Maria Santos'), findsOneWidget);
      expect(find.descendant(of: page, matching: find.text('PHP 80 / kg')), findsOneWidget);
      expect(find.descendant(of: page, matching: find.text('Malolos')), findsOneWidget);
      expect(find.text('Why are you reporting this listing?'), findsOneWidget);

      // Nothing written: says so under the field and sends nothing.
      await api.run(() async {
        await tester.tap(find.text('Submit Report'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Tell us why you are reporting this.'), findsOneWidget);
      expect(api.requests.where((r) => r.url.path.contains('/reports')), isEmpty);

      await tester.enterText(find.byType(TextField), '  The photos are of lemons  ');
      await tester.pump();
      expect(find.text('Tell us why you are reporting this.'), findsNothing);

      await api.run(() async {
        await tester.tap(find.text('Submit Report'));
        await tester.pumpAndSettle();
      });
      final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/reports/listings/12'));
      expect(sent.method, 'POST');
      expect(jsonDecode(sent.body), {'reason': 'The photos are of lemons'});
      expect(find.byType(ReportTargetPage), findsNothing);
      expect(find.byType(ListingPage), findsOneWidget);
      expect(find.text('Thanks for your report. We will look into it.'), findsOneWidget);
    });

    testWidgets('a refusal stays on the page and says why', (tester) async {
      usePhoneScreen(tester);
      const already = 'You have already reported this listing. We are looking into it.';
      final api = FakeApi({'POST /reports/listings/12': (_) => FakeApi.refused(409, already)});
      await openListing(tester, api: api);
      await openMenu(tester);
      // The page makes its API client as it opens.
      await api.run(() async {
        await tester.tap(find.text('Report This Listing'));
        await tester.pumpAndSettle();
      });

      await tester.enterText(find.byType(TextField), 'Fake listing');
      await api.run(() async {
        await tester.tap(find.text('Submit Report'));
        await tester.pumpAndSettle();
      });
      expect(find.byType(ReportTargetPage), findsOneWidget);
      expect(find.text(already), findsOneWidget);
    });
  });

  // In the default wide test window: the test font's square glyphs overflow
  // the profile header on a phone-width one.
  group('profile', () {
    FakeApi profileApi() => FakeApi({
          'GET /users/99/profile': (_) => {
                'user_id': _seller,
                'first_name': 'Maria',
                'last_name': 'Santos',
                'created_at': '2026-03-14T02:00:00.000Z',
                'followers_count': 0,
                'following_count': 0,
              },
          'POST /reports/users/99': (_) => {'report_id': 2},
        });

    Future<void> openSellerProfile(WidgetTester tester, FakeApi api) => api.run(() async {
          await tester.pumpWidget(MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfilePage.forSeller(sellerId: _seller, sellerName: 'Maria Santos'),
                )),
                child: const Text('Open'),
              ),
            ),
          ));
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
        });

    testWidgets("the kebab sits level with Back at the top right of someone else's profile", (tester) async {
      final api = profileApi();
      await openSellerProfile(tester, api);

      final back = tester.getCenter(find.byTooltip('Back'));
      final kebab = tester.getCenter(find.byTooltip('More options'));
      expect(kebab.dy, moreOrLessEquals(back.dy, epsilon: 1));
      expect(kebab.dx, greaterThan(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2));

      await openMenu(tester);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Report This Profile'), findsOneWidget);
    });

    testWidgets('reporting a profile shows who it is and files it', (tester) async {
      final api = profileApi();
      await openSellerProfile(tester, api);
      await openMenu(tester);
      await api.run(() async {
        await tester.tap(find.text('Report This Profile'));
        await tester.pumpAndSettle();
      });

      expect(find.text('REPORT PROFILE'), findsOneWidget);
      final page = find.byType(ReportTargetPage);
      expect(find.descendant(of: page, matching: find.text('Maria Santos')), findsOneWidget);
      expect(find.descendant(of: page, matching: find.textContaining('Member since')), findsOneWidget);
      expect(find.text('Why are you reporting this profile?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Asked me to pay outside the app');
      await api.run(() async {
        await tester.tap(find.text('Submit Report'));
        await tester.pumpAndSettle();
      });
      final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/reports/users/99'));
      expect(jsonDecode(sent.body), {'reason': 'Asked me to pay outside the app'});
      expect(find.byType(ReportTargetPage), findsNothing);
      expect(find.text('Thanks for your report. We will look into it.'), findsOneWidget);
    });

    testWidgets('your own profile offers Share only', (tester) async {
      final api = FakeApi({
        'GET /users/7/profile': (_) => {
              'user_id': _buyer,
              'first_name': 'Juan',
              'last_name': 'Cruz',
              'contact_number': '09171234567',
              'preferred_address_id': 1,
              'followers_count': 0,
              'following_count': 0,
            },
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();
      });
      await openMenu(tester);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Report This Profile'), findsNothing);
    });
  });
}
