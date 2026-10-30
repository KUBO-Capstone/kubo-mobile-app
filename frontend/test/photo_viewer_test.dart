import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/listing/screens/listing_page.dart';
import 'package:frontend/features/profile/widgets/profile_header_card.dart';
import 'package:frontend/shared/data/profile_records.dart';
import 'package:frontend/shared/data/synthetic_records.dart';
import 'package:frontend/shared/widgets/kubo_photo_viewer.dart';

const _photos = <String>[
  'assets/images/Placeholder_img.png',
  'assets/images/kubo_house.jpg',
  'assets/images/cover_landscape.jpg',
];

const _listing = SyntheticListingRecord(
  id: '12',
  title: 'Calamansi',
  price: 'PHP 80 / kg',
  locationLabel: 'Malolos',
  regionLabel: 'Region III',
  sellerLabel: 'Maria Santos',
  imageAssetPath: 'assets/images/Placeholder_img.png',
  images: _photos,
  productId: 12,
  sellerId: 99,
);

Finder get _viewerPages => find.descendant(of: find.byType(KuboPhotoViewer), matching: find.byType(PageView));

Future<void> _openViewerOnFirstPhoto(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: ListingPage(listing: _listing)));
  await tester.pump();
  await tester.tap(find.bySemanticsLabel('Photo 1 of 3'));
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

SyntheticProfileRecord _profile({String photoUrl = ''}) => SyntheticProfileRecord(
      displayName: 'Maria Santos',
      username: 'maria@kubo.local',
      locationLabel: 'Malolos',
      about: 'Calamansi grower.',
      joinedLabel: '06/01/2025',
      followingCount: 0,
      followersCount: 0,
      listingCount: 2,
      reviewScore: 0,
      reviewCount: 0,
      photoUrl: photoUrl,
    );

Widget _header({required bool isOwnProfile, String photoUrl = '', VoidCallback? onChangePhoto}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProfileHeaderCard(
          profile: _profile(photoUrl: photoUrl),
          isOwnProfile: isOwnProfile,
          onEditProfile: () {},
          onShare: () {},
          onSettings: () {},
          onFollow: () {},
          onMessage: () {},
          onChangePhoto: onChangePhoto ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping a listing photo opens it full screen on that photo', (tester) async {
    await _openViewerOnFirstPhoto(tester);

    expect(find.byType(KuboPhotoViewer), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('swiping moves through the photos and the carousel follows', (tester) async {
    await _openViewerOnFirstPhoto(tester);

    await tester.fling(_viewerPages, const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(KuboPhotoViewer), findsNothing);
    // Closed on photo 2, so the listing page is showing photo 2 as well.
    expect(find.bySemanticsLabel('Photo 2 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 1 of 3'), findsNothing);
  });

  testWidgets('dragging the photo down closes the viewer', (tester) async {
    await _openViewerOnFirstPhoto(tester);

    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 320));
    await tester.pumpAndSettle();
    expect(find.byType(KuboPhotoViewer), findsNothing);
  });

  testWidgets('a short drag springs back instead of closing', (tester) async {
    await _openViewerOnFirstPhoto(tester);

    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 45));
    await tester.pumpAndSettle();
    expect(find.byType(KuboPhotoViewer), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('double tap zooms in and holds the page until it zooms back out', (tester) async {
    await _openViewerOnFirstPhoto(tester);
    final photo = find.byType(InteractiveViewer);

    await _doubleTap(tester, photo);
    expect(tester.widget<PageView>(_viewerPages).physics, isA<NeverScrollableScrollPhysics>());
    expect(tester.widget<InteractiveViewer>(photo).panEnabled, isTrue);

    // Dragging a zoomed photo pans it; it does not turn the page.
    await tester.fling(_viewerPages, const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await _doubleTap(tester, photo);
    expect(tester.widget<PageView>(_viewerPages).physics, isNull);
    await tester.fling(_viewerPages, const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('one tap hides the controls and another brings them back', (tester) async {
    await _openViewerOnFirstPhoto(tester);
    double chromeOpacity() => tester
        .widget<AnimatedOpacity>(find.ancestor(of: find.byTooltip('Close'), matching: find.byType(AnimatedOpacity)).first)
        .opacity;

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(chromeOpacity(), 0);

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(chromeOpacity(), 1);
  });

  testWidgets("tapping someone's profile photo opens it full screen", (tester) async {
    await tester.pumpWidget(_header(isOwnProfile: false, photoUrl: '/uploads/profile/maria.jpg'));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Profile photo of Maria Santos'));
    await tester.pumpAndSettle();
    expect(find.byType(KuboPhotoViewer), findsOneWidget);
    // A single photo has nothing to count.
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('your own photo asks whether to view or change it', (tester) async {
    var changed = 0;
    await tester.pumpWidget(_header(isOwnProfile: true, photoUrl: '/uploads/profile/me.jpg', onChangePhoto: () => changed++));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Your profile photo'));
    await tester.pumpAndSettle();
    expect(find.text('View profile photo'), findsOneWidget);
    await tester.tap(find.text('Change profile photo'));
    await tester.pumpAndSettle();
    expect(changed, 1);
    expect(find.byType(KuboPhotoViewer), findsNothing);

    await tester.tap(find.bySemanticsLabel('Your profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View profile photo'));
    await tester.pumpAndSettle();
    expect(find.byType(KuboPhotoViewer), findsOneWidget);
  });

  testWidgets('without a photo your avatar goes straight to changing it', (tester) async {
    var changed = 0;
    await tester.pumpWidget(_header(isOwnProfile: true, onChangePhoto: () => changed++));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Your profile photo'));
    await tester.pumpAndSettle();
    expect(changed, 1);
    expect(find.text('View profile photo'), findsNothing);
  });
}
