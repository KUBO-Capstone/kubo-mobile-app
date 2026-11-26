import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/features/explore/widgets/listings_map.dart';
import 'package:frontend/shared/widgets/kubo_map_controls.dart';

import 'support/fake_api.dart';

// How far the app's maps reach: the Philippine Area of Responsibility, never
// the neighbours beyond it.

/// Whether what [camera] shows lies inside [kuboPhilippineArea]. flutter_map
/// rounds to whole pixels when it works out the visible bounds, so up to a
/// pixel past the edge at that zoom still counts as inside.
bool insideArea(MapCamera camera) {
  final view = camera.visibleBounds;
  final onePixel = 360 / (256 * math.pow(2, camera.zoom));
  final tolerance = onePixel;
  final area = kuboPhilippineArea;
  return view.south >= area.south - tolerance &&
      view.north <= area.north + tolerance &&
      view.west >= area.west - tolerance &&
      view.east <= area.east + tolerance;
}

MapCamera camera({required LatLng center, required double zoom, Size size = const Size(380, 420)}) => MapCamera(
      crs: const Epsg3857(),
      center: center,
      zoom: zoom,
      rotation: 0,
      nonRotatedSize: size,
    );

void main() {
  group('KuboContainCamera', () {
    const manila = LatLng(14.6, 121.0);

    test('a view already inside the area is left exactly as it is', () {
      final inside = camera(center: manila, zoom: 9);
      expect(identical(kuboMapBounds.constrain(inside), inside), isTrue);
    });

    test('zooming out past the limit stops where the area fills the map', () {
      final constrained = kuboMapBounds.constrain(camera(center: const LatLng(12.3, 122.5), zoom: 2));
      expect(constrained.zoom, greaterThan(2));
      expect(insideArea(constrained), isTrue);
      // One step further out would show past the area.
      final further = camera(center: constrained.center, zoom: constrained.zoom - 0.1);
      expect(insideArea(further), isFalse);
    });

    test('panning toward a neighbour is stopped at the area edge', () {
      // Centre dragged over Vietnam and over Indonesia.
      for (final center in const [LatLng(14.0, 106.0), LatLng(-2.0, 118.0)]) {
        final constrained = kuboMapBounds.constrain(camera(center: center, zoom: 7));
        expect(constrained.zoom, 7, reason: 'zoomed in enough already; only the centre moves');
        expect(insideArea(constrained), isTrue, reason: '$center');
      }
    });

    test('the limit follows the map size: a wider map cannot zoom out as far', () {
      final phone = kuboMapBounds.minZoomFor(camera(center: manila, zoom: 6));
      final tablet = kuboMapBounds.minZoomFor(camera(center: manila, zoom: 6, size: const Size(900, 700)));
      expect(tablet, greaterThan(phone));
    });

    test('the whole country can still be reached at the edges', () {
      for (final place in const [
        LatLng(4.6, 119.5), // Tawi-Tawi's southern islands
        LatLng(21.1, 121.9), // Batanes
        LatLng(10.5, 114.3), // Pag-asa, Kalayaan
      ]) {
        final constrained = kuboMapBounds.constrain(camera(center: place, zoom: 9));
        expect(constrained.visibleBounds.contains(place), isTrue, reason: '$place');
      }
    });

    test('a map not laid out yet is left alone', () {
      final unsized = camera(center: manila, zoom: 3, size: MapCamera.kImpossibleSize);
      expect(identical(kuboMapBounds.constrain(unsized), unsized), isTrue);
    });
  });

  group('the explore map', () {
    Future<MapController> pumpMap(WidgetTester tester, {required bool minimized}) async {
      await FakeApi().run(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListingsMap(listings: const [], minimized: minimized, onToggleMinimized: () {}),
              ),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 50));
      });
      return tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    }

    testWidgets('opens showing only the Philippine area', (tester) async {
      final controller = await pumpMap(tester, minimized: false);
      expect(insideArea(controller.camera), isTrue);
    });

    testWidgets('zooming far out settles at the limit, and zoom out dims there', (tester) async {
      final controller = await pumpMap(tester, minimized: false);
      controller.move(controller.camera.center, 2);
      await tester.pumpAndSettle();
      expect(insideArea(controller.camera), isTrue);

      final zoomOut = find.byWidgetPredicate((widget) => widget is KuboMapButton && widget.tooltip == 'Zoom out');
      expect(tester.widget<KuboMapButton>(zoomOut).onTap, isNull);
    });

    testWidgets('expanding the minimised map keeps the view inside the area', (tester) async {
      // A phone-width map: there the height, not the width, decides how far
      // out the expanded map may go, so growing taller can overshoot.
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Minimised at its furthest-out zoom: a short strip, so it fits there.
      final controller = await pumpMap(tester, minimized: true);
      controller.move(controller.camera.center, 2);
      await tester.pumpAndSettle();

      // Taller once expanded, which would show past the area until put back.
      await pumpMap(tester, minimized: false);
      await tester.pumpAndSettle();
      expect(insideArea(controller.camera), isTrue);
    });
  });
}
