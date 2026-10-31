import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/listing/screens/create_listing_page.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: CreateListingPage()));
  await tester.pump();
}

void main() {
  testWidgets('List it! on an empty draft marks what is missing', (tester) async {
    await _pumpPage(tester);
    await tester.tap(find.text('List it!'));
    await tester.pump();

    expect(find.text('Please complete the details marked in red.'), findsOneWidget);
    expect(find.text('Please add at least one photo.'), findsOneWidget);
    expect(find.text('Please choose a category.'), findsOneWidget);
    expect(find.text('Please enter a listing title.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Please choose a deal method'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Please enter a price.'), findsOneWidget);
    expect(find.text('Please choose a deal method'), findsOneWidget);
  });

  testWidgets('Add opens a second draft and offers Post all', (tester) async {
    await _pumpPage(tester);
    expect(find.text('Listing 1'), findsOneWidget);
    expect(find.textContaining('Post all'), findsNothing);

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(find.text('Listing 2'), findsOneWidget);
    expect(find.text('Post all (2)'), findsOneWidget);
    expect(find.byTooltip('Delete this draft'), findsOneWidget);
  });

  testWidgets('a template fills the description from the title', (tester) async {
    await _pumpPage(tester);
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Lakatan bananas, Baguio strawberries'), 'Carabao mango');
    await tester.scrollUntilVisible(find.text('Bullet points'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Bullet points'));
    await tester.pump();

    expect(find.textContaining('- Produce: Carabao mango'), findsOneWidget);
    // Let the market price lookup debounce finish.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('turning on pre-order makes the harvest date required', (tester) async {
    await _pumpPage(tester);
    await tester.scrollUntilVisible(find.text('Harvest date (Optional)'), 300, scrollable: find.byType(Scrollable).first);

    await tester.tap(find.text('Pre-order'));
    await tester.pump();
    expect(find.text('Expected harvest date'), findsOneWidget);

    await tester.tap(find.text('List it!'));
    await tester.pump();
    expect(find.text('Please pick the expected harvest date.'), findsOneWidget);
  });
}
