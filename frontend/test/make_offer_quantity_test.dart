import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/listing/widgets/make_offer_dialog.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/shared/data/session_store.dart';
import 'package:frontend/shared/data/synthetic_records.dart';

import 'support/fake_api.dart';

// The offer sheet's quantity field says at once when it asks for more than
// the listing has left.

final _listing = SyntheticListingRecord.fromJson({
  'product_id': 9,
  'seller_id': 3,
  'crop_name': 'Tomatoes',
  'base_price': 80,
  'unit_measurement': 'kg',
  'available_quantity': 5,
  'status': 'available',
  'seller_name': 'Grower One',
  'location_label': 'BAGUIO CITY',
  'region_label': 'CAR',
  'images': <String>[],
});

const _tooMuch = 'Only 5 kg available';

void main() {
  setUp(() {
    AuthService.store = MemorySessionStore();
    // A buyer with a complete profile, so the sheet opens.
    AuthService.currentUser = <String, dynamic>{
      'user_id': 7,
      'contact_number': '09171234567',
      'preferred_address_id': 1,
    };
  });
  tearDown(() => AuthService.currentUser = null);

  Future<FakeApi> openSheet(WidgetTester tester) async {
    // The seller's pickup and delivery options are not needed here; that
    // lookup simply fails.
    final api = FakeApi();
    await api.run(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMakeOfferDialog(context, _listing),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    });
    return api;
  }

  Finder quantityField() => find.byType(TextField).at(1);

  InputDecoration quantityDecoration(WidgetTester tester) => tester.widget<TextField>(quantityField()).decoration!;

  testWidgets('more than is available turns the field red and says how much there is', (tester) async {
    await openSheet(tester);

    await tester.enterText(quantityField(), '6');
    await tester.pump();

    expect(find.text(_tooMuch), findsOneWidget);
    expect(quantityDecoration(tester).errorText, _tooMuch);
    expect(quantityDecoration(tester).errorBorder?.borderSide.color, Colors.redAccent);
  });

  testWidgets('up to what is available shows nothing', (tester) async {
    await openSheet(tester);

    for (final amount in ['1', '4.5', '5']) {
      await tester.enterText(quantityField(), amount);
      await tester.pump();
      expect(find.text(_tooMuch), findsNothing, reason: amount);
      expect(quantityDecoration(tester).errorText, isNull, reason: amount);
    }
  });

  testWidgets('bringing the amount back down clears it as it is typed', (tester) async {
    await openSheet(tester);

    await tester.enterText(quantityField(), '50');
    await tester.pump();
    expect(find.text(_tooMuch), findsOneWidget);

    await tester.enterText(quantityField(), '3');
    await tester.pump();
    expect(find.text(_tooMuch), findsNothing);
  });

  testWidgets('a typo like "3 5" or "1.2532" turns the field red as well', (tester) async {
    await openSheet(tester);

    for (final (typed, message) in [
      ('3 5', 'Remove the space.'),
      ('1.2532', 'Up to 3 decimal places.'),
      ('2,5', 'Use a dot for decimals, e.g. 2.5.'),
    ]) {
      await tester.enterText(quantityField(), typed);
      await tester.pump();
      expect(quantityDecoration(tester).errorText, message, reason: typed);
      expect(find.text(message), findsOneWidget, reason: typed);
    }

    await tester.enterText(quantityField(), '2');
    await tester.pump();
    expect(quantityDecoration(tester).errorText, isNull);
  });

  testWidgets('the price field is checked the same way', (tester) async {
    await openSheet(tester);
    final priceField = find.byType(TextField).at(0);

    await tester.enterText(priceField, '80.555');
    await tester.pump();
    expect(tester.widget<TextField>(priceField).decoration!.errorText, 'Up to 2 decimal places.');
  });

  testWidgets('Make Offer on empty fields marks both in red and sends nothing', (tester) async {
    final api = await openSheet(tester);
    await tester.enterText(quantityField(), '');
    await tester.pump();

    await api.run(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Make Offer'));
      await tester.pumpAndSettle();
    });

    expect(find.text('Enter your price per kg.'), findsOneWidget);
    expect(find.text('Enter a quantity.'), findsOneWidget);
    expect(api.requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('Make Offer with too much sends nothing and does not repeat the message', (tester) async {
    final api = await openSheet(tester);
    await tester.enterText(find.byType(TextField).at(0), '75');
    await tester.enterText(quantityField(), '6');
    await tester.pump();

    await api.run(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Make Offer'));
      await tester.pumpAndSettle();
    });

    expect(find.text(_tooMuch), findsOneWidget, reason: 'only under the field');
    expect(api.requests.where((request) => request.method == 'POST'), isEmpty);
  });
}
