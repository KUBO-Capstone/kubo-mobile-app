import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/widgets/chat_message_bubble.dart';
import 'package:frontend/features/listing/screens/listing_page.dart';
import 'package:frontend/features/listing/widgets/fulfillment_picker.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/profile/screens/fulfillment_settings_page.dart';
import 'package:frontend/features/profile/screens/profile_page.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/fulfillment_service.dart';
import 'package:frontend/shared/data/message_service.dart';
import 'package:frontend/shared/data/negotiation_service.dart';
import 'package:frontend/shared/data/session_store.dart';
import 'package:frontend/shared/data/synthetic_records.dart';

import 'support/fake_api.dart';

Map<String, dynamic> _center(int id, String name, {required bool supported}) => {
      'center_id': id,
      'location_name': name,
      'location_label': 'Laguna',
      'region_label': 'Region IV-A',
      'address_line': '',
      'supported': supported,
    };

/// What `GET .../fulfillment` answers: centers 1 (Los Baños) and 2 (Calamba),
/// couriers Lalamove and LBC Express, with [centers] / [couriers] ticked.
/// Empty means nothing ticked, so everything counts as supported.
Map<String, dynamic> _fulfillment({
  List<int> centers = const [],
  List<String> couriers = const [],
  String source = 'profile',
  int? productId,
}) =>
    {
      'seller_id': 99,
      'product_id': productId,
      'source': source,
      'origin_label': 'LOS BAÑOS, LAGUNA',
      'origin_region': 'Region IV-A',
      'centers': [
        _center(1, 'Los Baños Bagsakan', supported: centers.isEmpty || centers.contains(1)),
        _center(2, 'Calamba Bagsakan', supported: centers.isEmpty || centers.contains(2)),
      ],
      'couriers': [
        for (final name in ['Lalamove', 'LBC Express']) {'name': name, 'supported': couriers.isEmpty || couriers.contains(name)},
      ],
      'configured_centers': centers.isNotEmpty,
      'configured_couriers': couriers.isNotEmpty,
    };

SellerFulfillment _reach({List<int> centers = const [], List<String> couriers = const []}) =>
    SellerFulfillment.fromJson(_fulfillment(centers: centers, couriers: couriers));

Map<String, dynamic> _body(FakeApi api, String method) =>
    jsonDecode(api.requests.lastWhere((r) => r.method == method).body) as Map<String, dynamic>;

void main() {
  group('FulfillmentPicker', () {
    Future<List<OfferFulfillment?>> pump(
      WidgetTester tester, {
      required FulfillmentChooser chooser,
      required SellerFulfillment reach,
      OfferFulfillment? value,
    }) async {
      final picks = <OfferFulfillment?>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FulfillmentPicker(
              reach: reach,
              allowsMeetup: true,
              allowsDelivery: true,
              value: value,
              chooser: chooser,
              onChanged: picks.add,
            ),
          ),
        ),
      ));
      return picks;
    }

    testWidgets("a buyer sees centers the seller cannot reach greyed out, and cannot pick them", (tester) async {
      final picks = await pump(
        tester,
        chooser: FulfillmentChooser.buyer,
        reach: _reach(centers: [1]),
        value: const OfferFulfillment.pickup(centerId: 0),
      );

      expect(find.text('Showing the centers this seller drops off at.'), findsOneWidget);
      expect(find.text("Not serviceable in seller's area"), findsOneWidget);
      // Supported first.
      expect(tester.getTopLeft(find.text('Los Baños Bagsakan')).dy, lessThan(tester.getTopLeft(find.text('Calamba Bagsakan')).dy));

      await tester.tap(find.text('Calamba Bagsakan'));
      await tester.pump();
      expect(picks, isEmpty);

      await tester.tap(find.text('Los Baños Bagsakan'));
      await tester.pump();
      expect(picks.single, const OfferFulfillment.pickup(centerId: 1, centerName: 'Los Baños Bagsakan'));
    });

    testWidgets('a buyer choosing courier sees where it is picked up from and only bookable couriers', (tester) async {
      final picks = await pump(
        tester,
        chooser: FulfillmentChooser.buyer,
        reach: _reach(couriers: ['LBC Express']),
        value: const OfferFulfillment.courier(courierName: ''),
      );
      expect(find.text('Pickup from LOS BAÑOS, LAGUNA'), findsOneWidget);
      await tester.tap(find.text('Lalamove'));
      await tester.pump();
      expect(picks, isEmpty);
      await tester.tap(find.text('LBC Express'));
      await tester.pump();
      expect(picks.single, const OfferFulfillment.courier(courierName: 'LBC Express'));
    });

    testWidgets('picking a method with a single supported option picks it for you', (tester) async {
      final picks = await pump(tester, chooser: FulfillmentChooser.buyer, reach: _reach(centers: [2]));
      await tester.tap(find.text('Pickup'));
      await tester.pump();
      expect(picks.single, const OfferFulfillment.pickup(centerId: 2, centerName: 'Calamba Bagsakan'));
    });

    testWidgets('a seller countering can take a center outside their usual ones', (tester) async {
      final picks = await pump(
        tester,
        chooser: FulfillmentChooser.seller,
        reach: _reach(centers: [1]),
        value: const OfferFulfillment.pickup(centerId: 0),
      );
      expect(find.text("Not serviceable in seller's area"), findsNothing);
      expect(find.text('Outside your usual centers'), findsOneWidget);
      await tester.tap(find.text('Calamba Bagsakan'));
      await tester.pump();
      expect(picks.single, const OfferFulfillment.pickup(centerId: 2, centerName: 'Calamba Bagsakan'));
    });

    test('a method alone is not a complete handover', () {
      expect(isCompleteFulfillment(null), isFalse);
      expect(isCompleteFulfillment(const OfferFulfillment.pickup(centerId: 0)), isFalse);
      expect(isCompleteFulfillment(const OfferFulfillment.courier(courierName: '')), isFalse);
      expect(isCompleteFulfillment(const OfferFulfillment.pickup(centerId: 3)), isTrue);
      expect(isCompleteFulfillment(const OfferFulfillment.courier(courierName: 'Lalamove')), isTrue);
    });
  });

  group('pickup & delivery settings', () {
    Future<FakeApi> pumpPage(WidgetTester tester, Map<String, FakeRoute> routes, Widget Function(FulfillmentService) page) async {
      final api = FakeApi(routes);
      // A tall screen, so the whole list is built and on screen.
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: page(FulfillmentService(client: api.client))));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('a listing follows the profile until the seller turns that off', (tester) async {
      final api = await pumpPage(
        tester,
        {
          'GET /products/8/fulfillment': (_) => _fulfillment(centers: [1], productId: 8),
          'PUT /products/8/fulfillment': (request) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return _fulfillment(
              centers: (body['center_ids'] as List).cast<int>(),
              couriers: (body['couriers'] as List).cast<String>(),
              source: 'listing',
              productId: 8,
            );
          },
        },
        (service) => FulfillmentSettingsPage.listing(productId: 8, listingTitle: 'Calamansi', service: service),
      );

      expect(find.text('Calamansi'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      // Read-only while it follows the profile, with where to change it.
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('Los Baños Bagsakan'), findsOneWidget);
      expect(find.text('Any courier'), findsOneWidget);
      expect(find.textContaining('Account settings → Pickup & delivery'), findsOneWidget);

      await tester.tap(find.text('Use My Profile Settings'));
      await tester.pumpAndSettle();
      // Starts from the profile's choices.
      final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
      expect(boxes.map((box) => box.value), [true, false, false, false]);

      await tester.tap(find.text('Calamba Bagsakan'));
      await tester.tap(find.text('Lalamove'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final body = _body(api, 'PUT');
      expect(body['custom'], isTrue);
      expect((body['center_ids'] as List).toSet(), {1, 2});
      expect(body['couriers'], ['Lalamove']);
      // Nothing was sent to the profile's settings.
      expect(api.requests.where((r) => r.url.path.contains('/users/')), isEmpty);
    });

    testWidgets('a listing with its own choices can go back to the profile', (tester) async {
      final api = await pumpPage(
        tester,
        {
          'GET /products/8/fulfillment': (_) => _fulfillment(centers: [2], source: 'listing', productId: 8),
          'PUT /products/8/fulfillment': (_) => _fulfillment(productId: 8),
        },
        (service) => FulfillmentSettingsPage.listing(productId: 8, listingTitle: 'Calamansi', service: service),
      );

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).map((box) => box.value), [false, true, false, false]);

      await tester.tap(find.text('Use My Profile Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_body(api, 'PUT')['custom'], isFalse);
    });

    testWidgets('the profile version saves the seller\'s own lists', (tester) async {
      final api = await pumpPage(
        tester,
        {
          'GET /users/99/fulfillment': (_) => _fulfillment(),
          'PUT /users/99/fulfillment': (_) => _fulfillment(couriers: ['LBC Express']),
        },
        (service) => FulfillmentSettingsPage.profile(userId: 99, service: service),
      );

      expect(find.byType(SwitchListTile), findsNothing);
      // Nothing narrowed down yet: nothing ticked, and buyers may pick any.
      expect(tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).every((box) => box.value == false), isTrue);
      expect(find.text('None ticked: buyers can pick any center.'), findsOneWidget);

      await tester.tap(find.text('LBC Express'));
      await tester.pump();
      expect(find.text('Buyers can only pick the 1 ticked.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_body(api, 'PUT'), {'center_ids': <dynamic>[], 'couriers': ['LBC Express']});
    });
  });

  group('lifetime earnings on the profile', () {
    const me = <String, dynamic>{'user_id': 7, 'first_name': 'Leonard', 'last_name': 'Cruz', 'email': 'leonard@kubo.local'};
    final earnings = {
      'total_earned': 3100,
      'completed_orders': 4,
      'in_progress_total': 0,
      'in_progress_deals': 0,
      'top_listings': <Object>[],
    };

    setUp(() {
      AuthService.store = MemorySessionStore();
      AuthService.currentUser = Map<String, dynamic>.of(me);
      ApiSession.token = 'test.token';
    });
    tearDown(() async => AuthService.logout());

    testWidgets('the owner sees their earnings banner', (tester) async {
      final api = FakeApi({
        'GET /users/7/profile': (_) => {...me, 'followers_count': 0, 'following_count': 0, 'completed_orders': 4},
        'GET /users/7/earnings': (_) => earnings,
      });
      await api.run(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
        await tester.pumpAndSettle();
      });
      expect(find.text('Lifetime Earnings'), findsOneWidget);
    });

    testWidgets('a visitor sees public trust figures only, and earnings are never fetched', (tester) async {
      final api = FakeApi({
        'GET /users/99/profile': (_) => {
              'user_id': 99,
              'first_name': 'Maria',
              'last_name': 'Santos',
              'created_at': '2026-03-14T02:00:00.000Z',
              'followers_count': 0,
              'following_count': 0,
              'completed_orders': 6,
            },
        'GET /users/99/earnings': (_) => earnings,
      });
      await api.run(() async {
        await tester.pumpWidget(MaterialApp(home: ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Lifetime Earnings'), findsNothing);
      expect(api.requests.where((r) => r.url.path.endsWith('/earnings')), isEmpty);
      await tester.scrollUntilVisible(find.text('Completed Orders'), 200, scrollable: find.byType(Scrollable).first);
      final card = find.ancestor(of: find.text('Completed Orders'), matching: find.byType(Column)).first;
      expect(find.descendant(of: card, matching: find.text('6')), findsOneWidget);
      expect(find.text('Member Since'), findsOneWidget);
    });
  });

  testWidgets('the listing top bar floats over the photos, then turns solid with the title', (tester) async {
    const listing = SyntheticListingRecord(
      id: '12',
      title: 'Calamansi',
      price: 'PHP 80 / kg',
      locationLabel: 'Malolos',
      regionLabel: 'Region III',
      sellerLabel: 'Maria Santos',
      imageAssetPath: 'assets/images/Placeholder_img.png',
      productId: 12,
      sellerId: 99,
    );
    await tester.pumpWidget(const MaterialApp(home: ListingPage(listing: listing)));
    await tester.pump();

    expect(find.byTooltip('Back'), findsOneWidget);
    // Share is inside the kebab menu now, not a button of its own.
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byTooltip('Share listing'), findsNothing);
    // Over the photos: only the page heading carries the title.
    expect(find.text('Calamansi'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    // Scrolled past the photos: the bar shows the title too, and stays put.
    expect(find.text('Calamansi'), findsNWidgets(2));
    expect(tester.getTopLeft(find.byTooltip('Back')).dy, lessThan(80));

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text('Calamansi'), findsOneWidget);
  });

  group('offer cards in the chat', () {
    MessageRecord message(MessageType type, {String? details, DeclineReason? reason}) => MessageRecord(
          id: '1',
          conversationId: 4,
          senderId: 99,
          senderName: 'Maria Santos',
          content: '',
          type: type,
          sentAt: DateTime(2026, 11, 1),
          negotiationId: 5,
          offerPrice: 80,
          offerQuantity: 10,
          offerDetails: details,
          declineReason: reason,
        );

    Future<void> pumpBubble(WidgetTester tester, MessageRecord record, {bool superseded = false}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ChatMessageBubble(message: record, isMine: false, superseded: superseded)),
        ));

    testWidgets('the live counter shows its terms and handover', (tester) async {
      await pumpBubble(tester, message(MessageType.counter, details: 'Pickup at Calamba Bagsakan'));
      expect(find.text('Counter Offer'), findsOneWidget);
      expect(find.text('PHP 80 × 10'), findsOneWidget);
      expect(find.text('Pickup at Calamba Bagsakan'), findsOneWidget);
      expect(find.text('Replaced'), findsNothing);
    });

    testWidgets('a replaced offer is faded, struck through and labelled', (tester) async {
      await pumpBubble(tester, message(MessageType.offer), superseded: true);
      expect(find.text('Replaced'), findsOneWidget);
      expect(tester.widget<Text>(find.text('PHP 80 × 10')).style?.decoration, TextDecoration.lineThrough);
      expect(tester.widget<Opacity>(find.ancestor(of: find.text('Offer'), matching: find.byType(Opacity)).first).opacity, lessThan(1));
    });

    testWidgets('a decline tells the buyer why', (tester) async {
      await pumpBubble(tester, message(MessageType.declined, reason: DeclineReason.bagsakanTooFar));
      expect(find.text('Offer Declined'), findsOneWidget);
      expect(find.text('Reason: Selected bagsakan is too far'), findsOneWidget);
    });
  });
}
