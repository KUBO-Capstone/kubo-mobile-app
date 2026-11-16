import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/explore/models/bagsakan_center.dart';
import 'package:frontend/features/explore/widgets/listings_map.dart';
import 'package:frontend/features/market/widgets/market_price_map.dart';
import 'package:frontend/shared/data/market_service.dart';
import 'package:frontend/shared/data/synthetic_records.dart';
import 'package:frontend/shared/widgets/kubo_map_controls.dart';

import 'support/fake_api.dart';

SyntheticListingRecord _listing(int id, {double? lat, double? lng, int sellerId = 1, String seller = 'Selma Tester'}) {
  return SyntheticListingRecord.fromJson({
    'product_id': id,
    'seller_id': sellerId,
    'crop_name': 'Crop $id',
    'base_price': 100,
    'unit_measurement': 'kg',
    'available_quantity': 5,
    'status': 'available',
    'seller_name': seller,
    'location_label': 'BAGUIO CITY',
    'region_label': 'CAR',
    'latitude': lat,
    'longitude': lng,
    'images': <String>[],
  });
}

Widget _host(Widget map) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: map))),
    );

MapOptions _options(WidgetTester tester) => tester.widget<FlutterMap>(find.byType(FlutterMap)).options;

void main() {
  // Tiles are fetched over HTTP; answer them locally.
  Future<void> pump(WidgetTester tester, Widget map) async {
    await FakeApi().run(() async {
      await tester.pumpWidget(_host(map));
      await tester.pump(const Duration(milliseconds: 50));
    });
  }

  group('the explore map', () {
    testWidgets('is drawn in listing mode even with no listing to plot', (tester) async {
      await pump(
        tester,
        ListingsMap(
          listings: const [],
          centers: const [],
          minimized: false,
          onToggleMinimized: () {},
          onPinModeChanged: (_) {},
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('No listings to show on the map yet.'), findsOneWidget);
      // Nothing to frame: the whole country.
      expect(_options(tester).initialCenter, kuboMapCountryCentre);
      expect(_options(tester).initialZoom, kuboMapCountryZoom);
    });

    testWidgets('says listings are still being placed when none has a point yet', (tester) async {
      await pump(
        tester,
        ListingsMap(listings: [_listing(1), _listing(2)], minimized: false, onToggleMinimized: () {}),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('not on the map yet'), findsOneWidget);
    });

    testWidgets('never rotates: no two-finger twist, no Ctrl-drag', (tester) async {
      await pump(
        tester,
        ListingsMap(listings: [_listing(1, lat: 16.41, lng: 120.59)], minimized: false, onToggleMinimized: () {}),
      );

      final interaction = _options(tester).interactionOptions;
      expect(InteractiveFlag.hasFlag(interaction.flags, InteractiveFlag.rotate), isFalse);
      expect(InteractiveFlag.hasFlag(interaction.flags, InteractiveFlag.drag), isTrue);
      expect(InteractiveFlag.hasFlag(interaction.flags, InteractiveFlag.pinchZoom), isTrue);
      expect(InteractiveFlag.hasFlag(interaction.flags, InteractiveFlag.doubleTapZoom), isTrue);
      expect(InteractiveFlag.hasFlag(interaction.flags, InteractiveFlag.scrollWheelZoom), isTrue);
      expect(_options(tester).initialRotation, 0);
      expect(interaction.cursorKeyboardRotationOptions.isKeyTrigger?.call(LogicalKeyboardKey.controlLeft), isFalse);
      expect(interaction.keyboardOptions.enableQERotating, isFalse);
    });

    testWidgets('a twist with two fingers leaves north up', (tester) async {
      await pump(
        tester,
        ListingsMap(listings: [_listing(1, lat: 16.41, lng: 120.59)], minimized: false, onToggleMinimized: () {}),
      );
      final centre = tester.getCenter(find.byType(FlutterMap));

      final first = await tester.startGesture(centre + const Offset(-60, 0), pointer: 1);
      final second = await tester.startGesture(centre + const Offset(60, 0), pointer: 2);
      await tester.pump();
      // Swing both fingers a quarter turn around the middle.
      for (var step = 1; step <= 6; step++) {
        final angle = step * 3.14159 / 12;
        final offset = Offset.fromDirection(angle, 60);
        await first.moveTo(centre - offset);
        await second.moveTo(centre + offset);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await first.up();
      await second.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(MapCamera.of(tester.element(find.byType(MarkerLayer))).rotation, 0);
    });

    testWidgets('zoom buttons step the map in and out', (tester) async {
      await pump(
        tester,
        ListingsMap(listings: [_listing(1, lat: 16.41, lng: 120.59)], minimized: false, onToggleMinimized: () {}),
      );
      double zoom() => MapCamera.of(tester.element(find.byType(MarkerLayer))).zoom;
      final start = zoom();

      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      expect(zoom(), closeTo(start + 1, 0.001));

      await tester.tap(find.byTooltip('Zoom out'));
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      expect(zoom(), closeTo(start - 1, 0.001));
      expect(MapCamera.of(tester.element(find.byType(MarkerLayer))).rotation, 0);
    });

    testWidgets('the collapsed strip keeps only the expand button', (tester) async {
      await pump(
        tester,
        ListingsMap(listings: [_listing(1, lat: 16.41, lng: 120.59)], minimized: true, onToggleMinimized: () {}),
      );

      expect(find.byTooltip('Expand map'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsNothing);
    });

    testWidgets('listings at one point share a pin that says how many', (tester) async {
      await pump(
        tester,
        ListingsMap(
          listings: [
            _listing(1, lat: 16.41, lng: 120.59),
            _listing(2, lat: 16.41, lng: 120.59, sellerId: 2, seller: 'Ana Racer'),
            _listing(3, lat: 14.55, lng: 121.02, sellerId: 3, seller: 'Buddy Tester'),
          ],
          minimized: false,
          onToggleMinimized: () {},
        ),
      );

      expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers, hasLength(2));
      expect(find.text('3 listings in 2 locations'), findsOneWidget);
      // The shared pin shows its count in place of the icon.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets("a town's pin lists every seller's listings there", (tester) async {
      await pump(
        tester,
        ListingsMap(
          listings: [
            _listing(1, lat: 16.41, lng: 120.59),
            _listing(2, lat: 16.41, lng: 120.59, sellerId: 2, seller: 'Ana Racer'),
          ],
          minimized: false,
          onToggleMinimized: () {},
        ),
      );

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.text('2 listings from 2 sellers'), findsOneWidget);
      expect(find.text('Selma Tester'), findsOneWidget);
      expect(find.text('Ana Racer'), findsOneWidget);
    });

    testWidgets('bagsakan mode still plots the centers', (tester) async {
      await pump(
        tester,
        ListingsMap(
          listings: const [],
          centers: [
            BagsakanCenter.fromJson({
              'center_id': 1,
              'location_name': 'Caloocan Kubo Bagsakan Center',
              'location_label': 'Caloocan',
              'region_label': 'NCR',
              'address_line': 'Caybiga',
              'latitude': 14.6832,
              'longitude': 120.9902,
            }),
          ],
          pinMode: MapPinMode.centers,
          minimized: false,
          onToggleMinimized: () {},
          onPinModeChanged: (_) {},
        ),
      );

      expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers, hasLength(1));
      expect(find.text('1 bagsakan center'), findsOneWidget);
    });
  });

  group('the market map', () {
    testWidgets('never rotates either, and has zoom buttons', (tester) async {
      final area = MarketAreaPrice.fromJson({
        'region': 'NCR',
        'region_name': 'National Capital Region',
        'area_type': 'market',
        'province_city': 'Quinta Market',
        'latitude': 14.5993,
        'longitude': 120.9818,
        'avg_price': 80,
        'lowest_price': 75,
        'highest_price': 85,
        'sample_size': 1,
        'recorded_at': '2026-11-01',
      });
      await FakeApi().run(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarketPriceMap(
                areas: [area],
                regionNames: const ['National Capital Region'],
                selectedRegionName: null,
                selectedArea: null,
                onRegionChanged: (_) {},
                onAreaSelected: (_) {},
                infoCard: null,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
      });

      final interaction = _options(tester).interactionOptions;
      expect(InteractiveFlag.hasFlag(interaction.flags, InteractiveFlag.rotate), isFalse);
      expect(interaction.cursorKeyboardRotationOptions.isKeyTrigger?.call(LogicalKeyboardKey.controlLeft), isFalse);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
    });
  });
}
