import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/widgets/app_svg_icon.dart';
import 'package:frontend/features/chat/widgets/messages_view.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/shell/providers/app_shell_controller.dart';
import 'package:frontend/shared/data/image_bytes_cache.dart';
import 'package:frontend/shared/widgets/kubo_bottom_navigation_bar.dart';
import 'package:frontend/shared/widgets/kubo_image.dart';

Uint8List _bytes(int length) => Uint8List.fromList(List<int>.filled(length, 7));

void main() {
  tearDown(() => ImageBytesCache.debugFetch = null);

  group('ImageBytesCache', () {
    test('downloads a photo once for every size that asks for it', () async {
      var fetches = 0;
      ImageBytesCache.debugFetch = (uri) async {
        fetches++;
        return _bytes(3);
      };
      final cache = ImageBytesCache(maxBytes: 100);

      final both = await Future.wait([cache.load('http://kubo/a.jpg'), cache.load('http://kubo/a.jpg')]);
      expect(fetches, 1);
      expect(identical(both[0], both[1]), isTrue);

      await cache.load('http://kubo/a.jpg');
      expect(fetches, 1);
    });

    test('drops the least recently used photo once over budget', () async {
      ImageBytesCache.debugFetch = (uri) async => _bytes(4);
      final cache = ImageBytesCache(maxBytes: 10);

      await cache.load('http://kubo/a.jpg');
      await cache.load('http://kubo/b.jpg');
      // Touch a, so b is now the oldest.
      await cache.load('http://kubo/a.jpg');
      await cache.load('http://kubo/c.jpg');

      expect(cache.contains('http://kubo/a.jpg'), isTrue);
      expect(cache.contains('http://kubo/b.jpg'), isFalse);
      expect(cache.contains('http://kubo/c.jpg'), isTrue);
      expect(cache.sizeInBytes, 8);
    });

    test('does not remember a failed download', () async {
      var fetches = 0;
      ImageBytesCache.debugFetch = (uri) async {
        fetches++;
        if (fetches == 1) throw Exception('offline');
        return _bytes(2);
      };
      final cache = ImageBytesCache(maxBytes: 100);

      await expectLater(cache.load('http://kubo/a.jpg'), throwsException);
      expect(cache.contains('http://kubo/a.jpg'), isFalse);

      await cache.load('http://kubo/a.jpg');
      expect(fetches, 2);
      expect(cache.contains('http://kubo/a.jpg'), isTrue);
    });
  });

  group('decode sizes', () {
    test('round up to a few shared steps', () {
      expect(kuboDecodeWidth(100), 128);
      expect(kuboDecodeWidth(512), 512);
      expect(kuboDecodeWidth(513), 640);
      expect(kuboDecodeWidth(9000), 2560);
    });

    testWidgets('a photo is decoded at the size it is drawn, not at full size', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: KuboImage('assets/images/Placeholder_img.png', width: 100, height: 100)),
          ),
        ),
      );

      final provider = tester.widget<Image>(find.byType(Image).first).image;
      expect(provider, isA<ResizeImage>());
      // 100 points covered by a 4:3 photo at 2x: 267 pixels, rounded up.
      expect((provider as ResizeImage).width, 384);
    });

    test('network photos share one provider per URL', () {
      expect(const KuboNetworkImage('http://kubo/a.jpg'), const KuboNetworkImage('http://kubo/a.jpg'));
      expect(kuboImageProvider('http://kubo/a.jpg'), isA<KuboNetworkImage>());
      expect(kuboImageProvider('assets/images/Placeholder_img.png'), isA<AssetImage>());
    });
  });

  group('inbox time labels', () {
    final now = DateTime(2026, 10, 29, 15, 30);

    test('read like a messaging app', () {
      expect(inboxTimeLabel(null, now: now), '');
      expect(inboxTimeLabel(now.subtract(const Duration(seconds: 20)), now: now), 'now');
      expect(inboxTimeLabel(now.subtract(const Duration(minutes: 5)), now: now), '5m');
      expect(inboxTimeLabel(now.subtract(const Duration(hours: 3)), now: now), '3h');
      // Yesterday evening is a weekday name, not "20h".
      expect(inboxTimeLabel(DateTime(2026, 10, 28, 19), now: now), 'Wed');
      expect(inboxTimeLabel(DateTime(2026, 3, 2, 9), now: now), 'Mar 2');
      expect(inboxTimeLabel(DateTime(2025, 3, 2, 9), now: now), '3/2/25');
    });
  });

  group('Profile tab icon', () {
    tearDown(() => AuthService.currentUser = null);

    Widget bar() => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: KuboBottomNavigationBar(
              currentTab: AppTab.home,
              onTabSelected: (_) {},
              onCreatePressed: () {},
            ),
          ),
        );

    testWidgets("shows the user's photo, and follows changes to it", (tester) async {
      AuthService.currentUser = <String, dynamic>{'user_id': 7, 'profile_photo_url': '/uploads/profile/me.jpg'};
      await tester.pumpWidget(bar());
      await tester.pump();
      expect(find.byType(KuboImage), findsOneWidget);

      AuthService.currentUser = <String, dynamic>{'user_id': 7};
      await tester.pump();
      expect(find.byType(KuboImage), findsNothing);
      expect(find.byType(AppSvgIcon), findsNWidgets(5));
    });
  });
}
