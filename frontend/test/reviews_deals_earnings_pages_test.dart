import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/deals/screens/deal_celebration_page.dart';
import 'package:frontend/features/earnings/screens/lifetime_earnings_page.dart';
import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/reviews/screens/write_review_page.dart';
import 'package:frontend/features/reviews/widgets/review_card.dart';
import 'package:frontend/shared/data/earnings_service.dart';
import 'package:frontend/shared/data/order_service.dart';
import 'package:frontend/shared/data/review_service.dart';
import 'package:frontend/shared/widgets/kubo_photo_viewer.dart';
import 'package:frontend/shared/widgets/kubo_star_rating.dart';

const _buyerId = 7;

final _deliveredOrder = OrderRecord(
  id: 12,
  negotiationId: 5,
  conversationId: 4,
  buyerId: _buyerId,
  sellerId: 3,
  buyerName: 'Juan Dela Cruz',
  sellerName: 'Maria Santos',
  productId: 8,
  cropName: 'Calamansi',
  unit: 'kg',
  quantity: 10,
  price: 80,
  total: 800,
  status: OrderStatus.delivered,
  deliveryMethod: DeliveryMethod.courier,
  orderDate: DateTime(2026, 10, 29),
  updatedAt: DateTime(2026, 10, 29),
);

class _FakeReviewService extends ReviewService {
  int? rating;
  String? comment;
  List<String>? tags;
  List<String>? photos;
  final uploads = <List<String>>[];

  @override
  Future<List<String>> uploadPhotos({required int orderId, required List<File> files}) async {
    uploads.add([for (final file in files) file.path]);
    return [for (var i = 0; i < files.length; i++) 'reviews/$orderId-$i.jpg'];
  }

  @override
  Future<ReviewRecord> submitReview({
    required int orderId,
    required int rating,
    String comment = '',
    List<String> tags = const <String>[],
    List<String> photos = const <String>[],
  }) async {
    this.rating = rating;
    this.comment = comment;
    this.tags = tags;
    this.photos = photos;
    return ReviewRecord(
      id: 1,
      orderId: orderId,
      reviewerId: _buyerId,
      revieweeId: 3,
      reviewerName: 'Juan Dela Cruz',
      reviewerRole: ReviewerRole.buyer,
      rating: rating,
      comment: comment,
      tags: tags,
      photos: photos,
      productId: 8,
      cropName: 'Calamansi',
    );
  }
}

Finder _star(int stars) =>
    find.descendant(of: find.byType(KuboStarRatingInput), matching: find.byType(InkResponse)).at(stars - 1);

/// Pushes [page] from a stub home so the test can read what it pops with.
Future<List<Object?>> _pushAndCollect(WidgetTester tester, Widget page) async {
  final results = <Object?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => results.add(await Navigator.of(context).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => page))),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return results;
}

const _pickerChannel = MethodChannel('plugins.flutter.io/image_picker');

/// The × on a picked photo (the badge itself, not the photo it sits on).
Finder _removeBadge(int photo) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Remove photo $photo');

void main() {
  setUp(() => AuthService.currentUser = {'user_id': _buyerId, 'first_name': 'Juan', 'last_name': 'Dela Cruz'});
  tearDown(() => AuthService.currentUser = null);

  testWidgets('a review needs stars; praise tags appear from 3 stars and are sent', (tester) async {
    final service = _FakeReviewService();
    await tester.pumpWidget(MaterialApp(home: WriteReviewPage(order: _deliveredOrder, service: service)));

    expect(find.text('How was your order from Maria Santos?'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit review')).onPressed, isNull);

    await tester.tap(_star(2));
    await tester.pumpAndSettle();
    expect(find.text('Fair'), findsOneWidget);
    expect(find.text('Fresh produce'), findsNothing);

    await tester.tap(_star(5));
    await tester.pumpAndSettle();
    expect(find.text('Excellent'), findsOneWidget);
    await tester.tap(find.text('On time'));
    await tester.tap(find.text('Fresh produce'));
    await tester.enterText(find.byType(TextField), 'Sobrang fresh!');
    await tester.tap(find.text('Submit review'));
    await tester.pump();

    expect(service.rating, 5);
    expect(service.comment, 'Sobrang fresh!');
    // Sent in the order the chips are listed, not the order they were tapped.
    expect(service.tags, ['fresh', 'on_time']);
    expect(service.uploads, isEmpty);
    expect(service.photos, isEmpty);
    expect(find.text('Thanks! Your review of Maria Santos is posted.'), findsOneWidget);
  });

  testWidgets('dropping below 3 stars clears picked tags', (tester) async {
    final service = _FakeReviewService();
    await tester.pumpWidget(MaterialApp(home: WriteReviewPage(order: _deliveredOrder, service: service, initialRating: 4)));
    await tester.tap(find.text('Fresh produce'));
    await tester.pump();
    await tester.tap(_star(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit review'));
    await tester.pump();
    expect(service.rating, 1);
    expect(service.tags, isEmpty);
  });

  group('review photos', () {
    late Directory dir;
    late List<String> picked;
    final calls = <String>[];

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kubo_review_photos');
      picked = [
        for (var i = 0; i < 7; i++) (File('${dir.path}${Platform.pathSeparator}p$i.jpg')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF])).path,
      ];
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pickerChannel, (call) async {
        calls.add(call.method);
        if (call.method == 'pickImage') return picked.first;
        // Like some platforms, ignore the limit: the page has to cap it.
        return picked.skip(1).toList();
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_pickerChannel, null);
      dir.deleteSync(recursive: true);
    });

    Future<void> addFrom(WidgetTester tester, String option) async {
      await tester.tap(find.text('+ Add Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('camera and gallery, capped at 5, remove one, upload before submit', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final service = _FakeReviewService();
      await tester.pumpWidget(MaterialApp(home: WriteReviewPage(order: _deliveredOrder, service: service, initialRating: 5)));
      // The line under the strip, so the strip clears the bottom Submit bar.
      await tester.scrollUntilVisible(find.textContaining('Your review is public'), 200, scrollable: find.byType(Scrollable).first);

      expect(find.text('Add Photos'), findsOneWidget);
      expect(find.text('Optional: Share photos of the produce quality or packaging'), findsOneWidget);
      expect(find.text('0/5'), findsOneWidget);

      await addFrom(tester, 'Take a photo');
      expect(calls, ['pickImage']);
      expect(find.text('1/5'), findsOneWidget);

      // The gallery hands back 6; only 4 slots are left.
      await addFrom(tester, 'Choose from gallery');
      expect(calls.last, isNot('pickImage'));
      expect(find.text('5/5'), findsOneWidget);
      expect(find.text('+ Add Photo'), findsNothing);
      expect(find.textContaining('Only the first 4 were added'), findsOneWidget);

      await tester.tap(_removeBadge(2));
      await tester.pumpAndSettle();
      expect(find.text('4/5'), findsOneWidget);
      // Back after the thumbnails, scrolled just past the edge of the strip.
      expect(find.text('+ Add Photo', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Submit review'));
      await tester.pump();
      await tester.pump();
      // Photo 2 (the first gallery pick, p1) was removed.
      expect(service.uploads, [
        [picked[0], picked[2], picked[3], picked[4]],
      ]);
      expect(service.photos, ['reviews/12-0.jpg', 'reviews/12-1.jpg', 'reviews/12-2.jpg', 'reviews/12-3.jpg']);
    });
  });

  testWidgets('a review card shows its photos as thumbnails that open full screen', (tester) async {
    const review = ReviewRecord(
      id: 1,
      orderId: 12,
      reviewerId: _buyerId,
      revieweeId: 3,
      reviewerName: 'Juan Dela Cruz',
      reviewerRole: ReviewerRole.buyer,
      rating: 5,
      comment: 'Fresh!',
      tags: [],
      photos: ['assets/images/Placeholder_img.png', 'assets/images/kubo_house.jpg'],
      productId: 8,
      cropName: 'Calamansi',
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ReviewCard(review: review))));
    expect(find.bySemanticsLabel('Review photo 1 of 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Review photo 2 of 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Review photo 2 of 2'));
    await tester.pumpAndSettle();
    expect(find.byType(KuboPhotoViewer), findsOneWidget);
  });

  testWidgets('a review card without photos shows no strip', (tester) async {
    const review = ReviewRecord(
      id: 2,
      orderId: 12,
      reviewerId: _buyerId,
      revieweeId: 3,
      reviewerName: 'Juan Dela Cruz',
      reviewerRole: ReviewerRole.buyer,
      rating: 4,
      comment: 'Good',
      tags: [],
      productId: 8,
      cropName: 'Calamansi',
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ReviewCard(review: review))));
    expect(find.bySemanticsLabel(RegExp('Review photo')), findsNothing);
  });

  testWidgets('buyer celebration after receiving: total shown, leads into the review', (tester) async {
    final results = await _pushAndCollect(
      tester,
      const DealCelebrationPage(
        isSeller: false,
        counterpartyName: 'Maria Santos',
        cropName: 'Calamansi',
        quantity: 10,
        unit: 'kg',
        price: 80,
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('You just closed a deal!'), findsOneWidget);
    expect(find.text('You received your order from Maria Santos.'), findsOneWidget);
    expect(find.text('Your total'), findsOneWidget);
    expect(find.text('₱800'), findsOneWidget);
    expect(find.text('10 kg Calamansi · ₱80/kg'), findsOneWidget);
    // Earnings are the seller's alone.
    expect(find.text('See lifetime earnings'), findsNothing);

    await tester.tap(find.text('Write a review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(results, [DealCelebrationAction.writeReview]);
  });

  testWidgets('seller celebration: deal amount and earnings shortcut', (tester) async {
    final results = await _pushAndCollect(
      tester,
      const DealCelebrationPage(
        isSeller: true,
        counterpartyName: 'Juan Dela Cruz',
        cropName: 'Calamansi',
        quantity: 10,
        unit: 'kg',
        price: 80.5,
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('You just closed a deal!'), findsOneWidget);
    expect(find.text('Juan Dela Cruz received the produce.'), findsOneWidget);
    expect(find.text('Deal amount'), findsOneWidget);
    expect(find.text('₱805'), findsOneWidget);

    await tester.tap(find.text('See lifetime earnings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(results, [DealCelebrationAction.viewEarnings]);
  });

  testWidgets('celebration when the review is already written offers only Done', (tester) async {
    final results = await _pushAndCollect(
      tester,
      const DealCelebrationPage(
        isSeller: false,
        canReview: false,
        counterpartyName: 'Maria Santos',
        cropName: 'Calamansi',
        quantity: 10,
        unit: 'kg',
        price: 80,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Write a review'), findsNothing);
    expect(find.text('Maybe later'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(results, [null]);
  });

  testWidgets('lifetime earnings shows the total, in-progress deals and top listings', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    int? askedFor;
    await tester.pumpWidget(MaterialApp(
      home: LifetimeEarningsPage(
        loader: (userId) async {
          askedFor = userId;
          return EarningsSummary(
            totalEarned: 3100,
            completedOrders: 4,
            inProgressTotal: 520,
            inProgressDeals: 2,
            firstSaleAt: DateTime(2026, 3, 2),
            topListings: const [
              TopEarningListing(productId: 8, cropName: 'Calamansi', unit: 'kg', status: 'available', earned: 1500, quantitySold: 20, orders: 2),
              TopEarningListing(productId: 9, cropName: 'Okra', unit: 'kg', status: 'out of stock', earned: 1600, quantitySold: 25, orders: 2),
            ],
          );
        },
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(askedFor, _buyerId);
    expect(find.text('₱3,100'), findsOneWidget);
    expect(find.text('from 4 completed orders since Mar 2026'), findsOneWidget);
    expect(find.text('Visible to you only.'), findsOneWidget);
    expect(find.text('₱520 on the way'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Okra'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Calamansi'), findsOneWidget);
    expect(find.text('₱1,600'), findsOneWidget);
    expect(find.text('25 kg sold · 2 orders'), findsOneWidget);
    expect(find.text('Create a listing'), findsOneWidget);
  });

  testWidgets('lifetime earnings before the first sale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LifetimeEarningsPage(
        loader: (_) async => const EarningsSummary(
          totalEarned: 0,
          completedOrders: 0,
          inProgressTotal: 0,
          inProgressDeals: 0,
          topListings: [],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('₱0'), findsOneWidget);
    expect(find.textContaining('completed order'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('Your first sale will show up here'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Your first sale will show up here'), findsOneWidget);
  });
}
