import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/deals/screens/deal_celebration_page.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/orders/screens/order_page.dart';
import 'package:frontend/features/reviews/screens/write_review_page.dart';
import 'package:frontend/shared/data/api_request.dart';
import 'package:frontend/shared/data/session_store.dart';

import 'support/fake_api.dart';

// Accepting an offer only starts the order. The deal is celebrated when the
// buyer confirms they have the produce, and the review follows from there.
void main() {
  const buyer = <String, dynamic>{'user_id': 7, 'first_name': 'Juan', 'last_name': 'Dela Cruz', 'email': 'juan@kubo.local'};

  Map<String, dynamic> order(String status) => {
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
        'delivery_method': 'courier',
        'courier_name': 'Lalamove',
        'order_date': '2026-11-10T02:00:00.000Z',
        'updated_at': '2026-11-10T02:00:00.000Z',
      };

  setUp(() {
    AuthService.store = MemorySessionStore();
    AuthService.currentUser = Map<String, dynamic>.of(buyer);
    ApiSession.token = 'test.token';
  });
  tearDown(() async => AuthService.logout());

  Future<FakeApi> openOrder(WidgetTester tester, String status) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var current = status;
    final api = FakeApi({
      'GET /orders/12': (_) => order(current),
      'PATCH /orders/12': (request) {
        expect((jsonDecode(request.body) as Map)['action'], 'deliver');
        current = 'delivered';
        return order(current);
      },
      'POST /negotiations/5/celebrated': (_) => {'negotiation_id': 5},
    });
    await api.run(() async {
      await tester.pumpWidget(const MaterialApp(home: OrderPage(orderId: 12, openChat: false)));
      await tester.pumpAndSettle();
    });
    return api;
  }

  testWidgets('an order that is on its way is not celebrated yet', (tester) async {
    await openOrder(tester, 'in transit');
    expect(find.byType(DealCelebrationPage), findsNothing);
    expect(find.text('Order received'), findsWidgets);
  });

  testWidgets('Order received confirms, celebrates, then opens the review', (tester) async {
    final api = await openOrder(tester, 'in transit');

    await api.run(() async {
      final button = find.widgetWithText(FilledButton, 'Order received');
      await tester.ensureVisible(button.first);
      await tester.tap(button.first);
      await tester.pumpAndSettle();
      expect(find.text('Order received?'), findsOneWidget);

      // Backing out changes nothing.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);

      await tester.tap(button.first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Order received')));
      // The celebration has looping animations; step time instead of settling.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    });

    expect(find.byType(DealCelebrationPage), findsOneWidget);
    expect(find.text('You received your order from Maria Santos.'), findsOneWidget);
    expect(api.requests.map((r) => '${r.method} ${r.url.path}'), contains('POST /api/negotiations/5/celebrated'));

    await api.run(() async {
      await tester.tap(find.text('Write a review'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
    expect(find.byType(WriteReviewPage), findsOneWidget);
    expect(find.text('How was your order from Maria Santos?'), findsOneWidget);
  });
}
