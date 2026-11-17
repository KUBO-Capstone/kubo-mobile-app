import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/orders/screens/hand_over_page.dart';
import 'package:frontend/features/orders/screens/order_page.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/session_store.dart';
import 'package:frontend/shared/widgets/kubo_photo_viewer.dart';

import 'support/fake_api.dart';

// The seller hands the order over on its own page (courier, tracking number,
// optional photos of the produce); afterwards both sides see those details
// on the order, and the tracking number can be copied.
void main() {
  const seller = <String, dynamic>{'user_id': 99, 'first_name': 'Maria', 'last_name': 'Santos', 'email': 'maria@kubo.local'};
  const buyer = <String, dynamic>{'user_id': 7, 'first_name': 'Juan', 'last_name': 'Dela Cruz', 'email': 'juan@kubo.local'};
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');

  Map<String, dynamic> order({
    String status = 'pending',
    String method = 'courier',
    String? tracking,
    List<String> photos = const [],
    String? shippedAt,
  }) =>
      {
        'order_id': 12,
        'negotiation_id': 5,
        'conversation_id': 4,
        'buyer_id': 7,
        'seller_id': 99,
        'buyer_name': 'Juan Dela Cruz',
        'seller_name': 'Maria Santos',
        'product_id': 8,
        'crop_name': 'Calamansi',
        'unit_measurement': 'kg',
        'quantity': 10,
        'negotiated_price': 80,
        'total_amount': 800,
        'order_status': status,
        'delivery_method': method,
        if (method == 'courier') 'courier_name': 'Lalamove',
        if (method == 'meetup') ...{'drop_off_center_id': 1, 'center_name': 'Los Baños Bagsakan', 'center_location': 'Los Baños'},
        'tracking_number': tracking,
        'handover_photos': photos,
        'shipped_at': shippedAt,
        'order_date': '2026-11-10T02:00:00.000Z',
        'updated_at': '2026-11-10T02:00:00.000Z',
      };

  late Directory dir;
  late List<String> clipboard;

  setUp(() {
    AuthService.store = MemorySessionStore();
    ApiSession.token = 'test.token';
    dir = Directory.systemTemp.createTempSync('kubo_handover');
    final photo = (File('${dir.path}${Platform.pathSeparator}parcel.jpg')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF])).path;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pickerChannel, (call) async => call.method == 'pickImage' ? photo : [photo]);
    clipboard = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      if (call.method == 'Clipboard.getData') return {'text': '  JT-PASTED-77  '};
      return null;
    });
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pickerChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    dir.deleteSync(recursive: true);
    await AuthService.logout();
  });

  // The photo upload reads the picked file with real I/O, which the test's
  // fake clock never finishes on its own: give it real time, then settle.
  Future<void> submit(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openOrder(WidgetTester tester, FakeApi api) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await api.run(() async {
      await tester.pumpWidget(const MaterialApp(home: OrderPage(orderId: 12, openChat: false)));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('the seller hands over to the courier with a tracking number and a photo', (tester) async {
    AuthService.currentUser = Map<String, dynamic>.of(seller);
    var current = order();
    final api = FakeApi({
      'GET /orders/12': (_) => current,
      'POST /orders/12/handover/photos': (_) => {
            'images': ['https://example.test/handovers/1.jpg'],
          },
      'PATCH /orders/12': (request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return current = order(
          status: 'in transit',
          tracking: body['tracking_number'] as String?,
          photos: (body['photos'] as List).cast<String>(),
          shippedAt: '2026-11-12T03:00:00.000Z',
        );
      },
    });
    await openOrder(tester, api);

    await api.run(() async {
      await tester.tap(find.text('Hand over to courier'));
      await tester.pumpAndSettle();
      expect(find.byType(HandOverPage), findsOneWidget);
      expect(find.text('Order #12 · Calamansi'), findsOneWidget);
      // The courier agreed in the offer is filled in.
      expect(find.widgetWithText(TextField, 'Lalamove'), findsOneWidget);
      expect(find.text('Agreed in the offer'), findsOneWidget);
      expect(find.text('Photo of the produce (optional)'), findsOneWidget);

      await tester.tap(find.byTooltip('Paste tracking number'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'JT-PASTED-77'), findsOneWidget);

      await tester.tap(find.text('+ Add Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(find.text('1/5'), findsOneWidget);

      await submit(tester, 'Mark as shipped');
      await tester.pumpAndSettle();
    });

    final calls = api.requests.map((r) => '${r.method} ${r.url.path}').toList();
    expect(calls.indexOf('POST /api/orders/12/handover/photos'), lessThan(calls.indexOf('PATCH /api/orders/12')));
    final sent = jsonDecode(api.requests.lastWhere((r) => r.method == 'PATCH').body) as Map<String, dynamic>;
    expect(sent, {
      'action': 'ship',
      'courier_name': 'Lalamove',
      'tracking_number': 'JT-PASTED-77',
      'photos': ['https://example.test/handovers/1.jpg'],
    });

    // Back on the order, with the details.
    expect(find.byType(HandOverPage), findsNothing);
    expect(find.text('JT-PASTED-77'), findsOneWidget);
    expect(find.text('Photos at handover'), findsOneWidget);
    expect(find.bySemanticsLabel('Handover photo 1 of 1'), findsOneWidget);
    expect(find.text('Shipped'), findsOneWidget);
  });

  testWidgets('a failed ship keeps the page and does not upload the photos twice', (tester) async {
    AuthService.currentUser = Map<String, dynamic>.of(seller);
    var attempts = 0;
    final api = FakeApi({
      'GET /orders/12': (_) => order(),
      'POST /orders/12/handover/photos': (_) => {
            'images': ['https://example.test/handovers/1.jpg'],
          },
      'PATCH /orders/12': (_) => ++attempts == 1
          ? FakeApi.refused(500, 'Something went wrong')
          : order(status: 'in transit', photos: ['https://example.test/handovers/1.jpg']),
    });
    await openOrder(tester, api);

    await api.run(() async {
      await tester.tap(find.text('Hand over to courier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Add Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Tracking number'), 'LBC123');

      await submit(tester, 'Mark as shipped');
      await tester.pumpAndSettle();
      expect(find.byType(HandOverPage), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget, reason: 'the photo is still there');

      await submit(tester, 'Mark as shipped');
      await tester.pumpAndSettle();
    });
    expect(find.byType(HandOverPage), findsNothing);
    expect(api.requests.where((r) => r.url.path.endsWith('/handover/photos')), hasLength(1));
  });

  testWidgets('a bagsakan drop-off shows the center and asks only for photos', (tester) async {
    AuthService.currentUser = Map<String, dynamic>.of(seller);
    final api = FakeApi({
      'GET /orders/12': (_) => order(method: 'meetup'),
      'PATCH /orders/12': (_) => order(method: 'meetup', status: 'in transit', shippedAt: '2026-11-12T03:00:00.000Z'),
    });
    await openOrder(tester, api);

    await api.run(() async {
      await tester.tap(find.text('Mark as dropped off at center'));
      await tester.pumpAndSettle();
      expect(find.text('Drop off at the center'), findsOneWidget);
      expect(find.text('Los Baños Bagsakan'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Tracking number'), findsNothing);

      await tester.tap(find.text('Mark as dropped off'));
      await tester.pumpAndSettle();
    });
    // No photos picked: nothing uploaded, an empty list sent.
    expect(api.requests.where((r) => r.url.path.endsWith('/handover/photos')), isEmpty);
    expect((jsonDecode(api.requests.lastWhere((r) => r.method == 'PATCH').body) as Map)['photos'], isEmpty);
    expect(find.text('Dropped off'), findsOneWidget);
  });

  testWidgets('the buyer sees the shipped details and can copy the tracking number', (tester) async {
    AuthService.currentUser = Map<String, dynamic>.of(buyer);
    final api = FakeApi({
      'GET /orders/12': (_) => order(
            status: 'in transit',
            tracking: 'JT0001234567',
            photos: ['https://example.test/handovers/1.jpg', 'https://example.test/handovers/2.jpg'],
            shippedAt: '2026-11-12T03:00:00.000Z',
          ),
    });
    await openOrder(tester, api);

    expect(find.text('Lalamove'), findsOneWidget);
    expect(find.text('JT0001234567'), findsOneWidget);
    expect(find.text('Hand over to courier'), findsNothing);

    await tester.tap(find.byTooltip('Copy tracking number'));
    await tester.pump();
    expect(clipboard, ['JT0001234567']);
    expect(find.text('Tracking number copied'), findsOneWidget);

    expect(find.bySemanticsLabel('Handover photo 1 of 2'), findsOneWidget);
    await api.run(() async {
      await tester.tap(find.bySemanticsLabel('Handover photo 2 of 2'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(KuboPhotoViewer), findsOneWidget);
  });

  testWidgets('an order shipped without a tracking number says to check the chat', (tester) async {
    AuthService.currentUser = Map<String, dynamic>.of(buyer);
    final api = FakeApi({'GET /orders/12': (_) => order(status: 'in transit')});
    await openOrder(tester, api);
    expect(find.byTooltip('Copy tracking number'), findsNothing);
    expect(find.text('See chat'), findsOneWidget);
    expect(find.text('Photos at handover'), findsNothing);
  });
}
