import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/search/providers/search_page_controller.dart';
import 'package:frontend/features/search/screens/search_page.dart';
import 'package:frontend/features/search/screens/search_results_page.dart';
import 'package:frontend/features/search/widgets/search_suggestion_card.dart';
import 'package:frontend/features/search/widgets/search_suggestion_tile.dart';
import 'package:frontend/shared/data/listing_service.dart';

import 'support/fake_api.dart';

/// Answers `fetchSuggestions` from a table, optionally holding an answer
/// back until the test lets it go.
class _FakeListings extends ListingService {
  _FakeListings(this.answers);

  final Map<String, List<ListingSuggestion>> answers;
  final List<String> asked = <String>[];
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};
  bool failing = false;

  @override
  Future<List<ListingSuggestion>> fetchSuggestions({String query = '', int? limit}) async {
    asked.add(query);
    await gates[query]?.future;
    if (failing) throw Exception('offline');
    return answers[query] ?? const <ListingSuggestion>[];
  }
}

ListingSuggestion _listing(String text, {int count = 1}) =>
    ListingSuggestion(text: text, type: SuggestionType.listing, listingCount: count);

Map<String, dynamic> _row(String text, {String type = 'listing', int count = 1}) =>
    {'text': text, 'type': type, 'listing_count': count, 'image': null};

final Duration _afterTypingPause = SearchPageController.typingPause + const Duration(milliseconds: 60);

void main() {
  group('SearchPageController', () {
    test('popular produce comes from the server', () async {
      final controller = SearchPageController(
        service: _FakeListings({'': [_listing('Sitaw', count: 3), _listing('Kamote')]}),
      );
      expect(controller.isLoadingPopular, isTrue);

      await controller.loadPopular();

      expect(controller.isLoadingPopular, isFalse);
      expect(controller.popular.map((s) => s.text), ['Sitaw', 'Kamote']);
      expect(controller.popularFailed, isFalse);
      controller.dispose();
    });

    test('a failed first load says so; a failed refresh keeps what was shown', () async {
      final listings = _FakeListings({'': [_listing('Sitaw')]})..failing = true;
      final controller = SearchPageController(service: listings);

      await controller.loadPopular();
      expect(controller.popularFailed, isTrue);
      expect(controller.popular, isEmpty);

      listings.failing = false;
      await controller.loadPopular();
      expect(controller.popularFailed, isFalse);
      expect(controller.popular.single.text, 'Sitaw');

      listings.failing = true;
      await controller.loadPopular();
      expect(controller.popularFailed, isFalse);
      expect(controller.popular.single.text, 'Sitaw');
      controller.dispose();
    });

    test('typing asks once, after the pause, for the latest text', () async {
      final listings = _FakeListings({'man': [_listing('Mango'), _listing('Manggang hilaw')]});
      final controller = SearchPageController(service: listings);

      controller.updateTypedQuery('m');
      controller.updateTypedQuery('ma');
      controller.updateTypedQuery('man');
      expect(controller.isTyping, isTrue);
      expect(controller.isLoadingMatches, isTrue);
      expect(listings.asked, isEmpty, reason: 'nothing is asked while the user is still typing');

      await Future<void>.delayed(_afterTypingPause);

      expect(listings.asked, ['man']);
      expect(controller.matches.map((s) => s.text), ['Mango', 'Manggang hilaw']);
      expect(controller.isLoadingMatches, isFalse);
      controller.dispose();
    });

    test('an answer for text the user has moved on from is dropped', () async {
      final listings = _FakeListings({
        'ma': [_listing('Mais')],
        'mang': [_listing('Mango')],
      });
      listings.gates['ma'] = Completer<void>();
      final controller = SearchPageController(service: listings);

      controller.updateTypedQuery('ma');
      await Future<void>.delayed(_afterTypingPause);
      controller.updateTypedQuery('mang');
      await Future<void>.delayed(_afterTypingPause);
      expect(controller.matches.single.text, 'Mango');

      // The slow answer for "ma" arrives last and must not replace "mang"'s.
      listings.gates['ma']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(controller.matches.single.text, 'Mango');
      controller.dispose();
    });

    test('clearing the field goes back to browsing at once, without asking', () async {
      final listings = _FakeListings({'ma': [_listing('Mais')]});
      final controller = SearchPageController(service: listings);
      controller.updateTypedQuery('ma');
      await Future<void>.delayed(_afterTypingPause);
      expect(controller.matches, isNotEmpty);

      controller.updateTypedQuery('   ');

      expect(controller.isTyping, isFalse);
      expect(controller.matches, isEmpty);
      await Future<void>.delayed(_afterTypingPause);
      expect(listings.asked, ['ma']);
      controller.dispose();
    });

    test('a failed lookup leaves an empty list rather than a stuck spinner', () async {
      final listings = _FakeListings({})..failing = true;
      final controller = SearchPageController(service: listings);

      controller.updateTypedQuery('ma');
      await Future<void>.delayed(_afterTypingPause);

      expect(controller.isLoadingMatches, isFalse);
      expect(controller.matches, isEmpty);
      controller.dispose();
    });

    test("the user's own matching searches lead, and are not listed twice", () async {
      final listings = _FakeListings({'man': [_listing('mango'), _listing('Mangosteen')]});
      final controller = SearchPageController(service: listings)
        ..submitSearch('Kamote')
        ..submitSearch('Mango')
        ..submitSearch('Romblon mangoes');

      controller.updateTypedQuery('man');
      await Future<void>.delayed(_afterTypingPause);

      expect(controller.matchingRecentSearches, ['Romblon mangoes', 'Mango']);
      expect(controller.freshMatches.map((s) => s.text), ['Mangosteen']);
      controller.dispose();
    });

    test('disposing mid-pause cancels the lookup', () async {
      final listings = _FakeListings({'ma': [_listing('Mais')]});
      final controller = SearchPageController(service: listings);
      controller.updateTypedQuery('ma');
      controller.dispose();

      await Future<void>.delayed(_afterTypingPause);

      expect(listings.asked, isEmpty);
    });
  });

  group('SearchSuggestionTile', () {
    testWidgets('sets the typed part apart from what the suggestion adds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchSuggestionTile(icon: Icons.search, text: 'Sweet mango', typed: 'MAN', onTap: () {}),
          ),
        ),
      );

      final spans = <(String, FontWeight?)>[];
      final label = find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText() == 'Sweet mango');
      tester.widget<RichText>(label).text.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add((span.text!, span.style?.fontWeight));
        return true;
      });
      expect(spans, [('Sweet ', FontWeight.w700), ('man', null), ('go', FontWeight.w700)]);
    });
  });

  group('SearchPage', () {
    // A tall, phone-shaped screen: on the default 800x600 test surface each
    // card is so large that the grid's second row is never built. (A little
    // wider than a real phone because the test font's glyphs are square, and
    // "Profile" in the bottom bar would wrap at 412.)
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(480, 960);
      view.devicePixelRatio = 1;
      addTearDown(view.reset);
    });

    FakeApi api() => FakeApi({
          'GET /products/suggestions': (request) {
            final q = request.url.queryParameters['q'];
            if (q == null) return [_row('Sitaw fresh bundle', count: 2), _row('Kamote'), _row('Okra')];
            if (q == 'ka') return [_row('Kamote'), _row('Kawit', type: 'place'), _row('Karla Tester', type: 'seller')];
            return <dynamic>[];
          },
          'GET /products': (_) => <dynamic>[],
        });

    testWidgets('shows what is popular right now instead of sample cards', (tester) async {
      final fake = api();
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();
      });

      expect(find.byType(SearchSuggestionCard), findsNWidgets(3));
      expect(find.text('Sitaw fresh bundle'), findsOneWidget);
      expect(find.text('2 listings'), findsOneWidget);
      expect(find.text('Coconut sa Caybiga'), findsNothing);
    });

    testWidgets('says so when there is nothing to suggest yet', (tester) async {
      final fake = FakeApi({'GET /products/suggestions': (_) => <dynamic>[]});
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();
      });

      expect(find.byType(SearchSuggestionCard), findsNothing);
      expect(find.textContaining('once growers post listings'), findsOneWidget);
    });

    testWidgets('offers a retry when suggestions cannot be loaded', (tester) async {
      var online = false;
      final fake = FakeApi({
        'GET /products/suggestions': (_) => online ? [_row('Kamote')] : FakeApi.refused(500, 'Server error'),
      });
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();
        expect(find.textContaining('Could not load suggestions'), findsOneWidget);

        online = true;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
      });

      expect(find.byType(SearchSuggestionCard), findsOneWidget);
      expect(find.textContaining('Could not load suggestions'), findsNothing);
    });

    testWidgets('typing swaps the page for suggestions that follow the text', (tester) async {
      final fake = api();
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'ka');
        await tester.pump();
        // At once: the row for exactly what was typed, and no browse sections.
        expect(find.text('Search for "ka"'), findsOneWidget);
        expect(find.text('Recent searches'), findsNothing);
        expect(find.byType(SearchSuggestionCard), findsNothing);

        await tester.pump(_afterTypingPause);
        await tester.pumpAndSettle();
      });

      expect(find.byType(SearchSuggestionTile), findsNWidgets(4));
      expect(find.text('Town'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      final asked = fake.requests.where((r) => r.url.path.endsWith('/suggestions')).map((r) => r.url.queryParameters['q']);
      expect(asked, [null, 'ka'], reason: 'one request for the popular list, one for the typed text');
    });

    testWidgets('clearing the field brings the browse sections back', (tester) async {
      final fake = api();
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ka');
        await tester.pump(_afterTypingPause);
        await tester.pumpAndSettle();

        // The field's clear button.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      });

      expect(find.byType(SearchSuggestionTile), findsNothing);
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.byType(SearchSuggestionCard), findsNWidgets(3));
    });

    testWidgets('tapping a suggestion searches for it and remembers the search', (tester) async {
      final fake = api();
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ka');
        await tester.pump(_afterTypingPause);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(SearchSuggestionTile, 'Town'));
        await tester.pumpAndSettle();

        expect(find.byType(SearchResultsPage), findsOneWidget);
        expect(find.text('Results for "Kawit"'), findsOneWidget);
        expect(
          fake.requests.where((r) => r.url.path == '/api/products').map((r) => r.url.queryParameters['q']),
          ['Kawit'],
        );

        // Back on the search page, cleared: the search is in the history.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      });

      expect(find.text('Kawit'), findsOneWidget);
    });

    testWidgets('tapping a popular card searches for it', (tester) async {
      final fake = api();
      await fake.run(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchPage()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Okra'));
        await tester.pumpAndSettle();
      });

      expect(find.text('Results for "Okra"'), findsOneWidget);
    });
  });
}
