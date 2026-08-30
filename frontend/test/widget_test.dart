// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';
import 'package:frontend/features/listing/screens/listing_page.dart';
import 'package:frontend/shared/data/synthetic_records.dart';

// Verifies that the app boots to the login screen and basic navigation works.
void main() {
  // Confirms the initial screen shows the branding and auth entry buttons.
  testWidgets('shows the login page', (WidgetTester tester) async {
    await tester.pumpWidget(const KuboApp());

    expect(find.text('KUBO'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
  });

  // Confirms the create-account flow opens the onboarding page and returns cleanly.
  testWidgets('navigates to create account and back', (WidgetTester tester) async {
    await tester.pumpWidget(const KuboApp());

    final createAccountButton = find.widgetWithText(TextButton, 'Create account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('First time here?'), findsOneWidget);
    expect(find.text('Back to login'), findsOneWidget);

    final backToLoginButton = find.text('Back to login');
    await tester.ensureVisible(backToLoginButton);
    await tester.tap(backToLoginButton);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('displays listing details for a selected listing', (WidgetTester tester) async {
    const listing = SyntheticListingRecord(
      id: 'listing-0',
      title: 'Fresh harvested tomatoes bundle',
      price: 'PHP 120',
      locationLabel: 'Caloocan',
      regionLabel: 'NCR',
      sellerLabel: 'Kubo Grower 1',
      imageAssetPath: 'assets/images/Placeholder_img.png',
    );

    await tester.pumpWidget(const MaterialApp(home: ListingPage(listing: listing)));

    expect(find.text('Fresh harvested tomatoes bundle'), findsOneWidget);
    expect(find.text('PHP 120'), findsOneWidget);
    expect(find.text('Caloocan'), findsOneWidget);
    expect(find.text('Kubo Grower 1'), findsOneWidget);
    expect(find.text('About this listing'), findsOneWidget);
  });
}
