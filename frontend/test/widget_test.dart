// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app.dart';

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
}
