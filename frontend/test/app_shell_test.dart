import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/profile/screens/profile_page.dart';
import 'package:frontend/features/shell/providers/app_shell_controller.dart';
import 'package:frontend/features/shell/screens/app_shell.dart';
import 'package:frontend/shared/widgets/kubo_bottom_navigation_bar.dart';

/// The item labelled [label] in whichever bottom bar is on screen.
Finder navItem(String label) => find.descendant(
      of: find.byType(KuboBottomNavigationBar),
      matching: find.text(label),
    );

void main() {
  setUp(() {
    AuthService.currentUser = <String, dynamic>{
      'user_id': 7,
      'first_name': 'Leonard',
      'last_name': 'Cruz',
      'email': 'leonard@kubo.local',
    };
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('a tab keeps its state when you switch away and back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell(initialTab: AppTab.search)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'mango');
    await tester.tap(navItem('Market'));
    await tester.pumpAndSettle();
    expect(find.text('MARKET'), findsOneWidget);
    expect(find.text('mango'), findsNothing);

    await tester.tap(navItem('Search'));
    await tester.pumpAndSettle();
    expect(find.text('mango'), findsOneWidget);
    expect(find.text('MARKET'), findsNothing);
  });

  testWidgets("Profile in the bar on someone else's profile opens your own", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    // The visited profile is reached from Home, so Home stays highlighted.
    expect(AppShellController.instance.current, AppTab.home);

    await tester.tap(navItem('Profile'));
    await tester.pumpAndSettle();

    expect(AppShellController.instance.current, AppTab.profile);
    expect(find.text('Maria Santos'), findsNothing);
    expect(find.text('Leonard Cruz'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('another tab in that bar pops back to the shell instead of stacking pages', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => ProfilePage.forSeller(sellerId: 99, sellerName: 'Maria Santos')),
    );
    await tester.pumpAndSettle();

    await tester.tap(navItem('Market'));
    await tester.pumpAndSettle();

    expect(AppShellController.instance.current, AppTab.market);
    expect(find.text('MARKET'), findsOneWidget);
    // Only the shell is left: Back has nothing to return to.
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('your own profile reached from a listing gets a back button and the bar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute<void>(builder: (_) => ProfilePage.forSeller(sellerId: 7, sellerName: 'Leonard Cruz')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(navItem('Profile'), findsOneWidget);
  });

  testWidgets('tapping the open tab again scrolls it to the top, then focuses search', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell(initialTab: AppTab.search)));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
        .first;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, greaterThan(0));

    await tester.tap(navItem('Search'));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);

    final field = tester.state<EditableTextState>(find.byType(EditableText));
    expect(field.widget.focusNode.hasFocus, isFalse);
    await tester.tap(navItem('Search'));
    await tester.pumpAndSettle();
    expect(field.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('switching tabs drops the keyboard of the tab being left', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell(initialTab: AppTab.search)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final field = tester.state<EditableTextState>(find.byType(EditableText));
    expect(field.widget.focusNode.hasFocus, isTrue);

    await tester.tap(navItem('Market'));
    await tester.pumpAndSettle();
    expect(field.widget.focusNode.hasFocus, isFalse);
  });

  testWidgets('back on another tab goes Home instead of leaving the app', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();

    await tester.tap(navItem('Market'));
    await tester.pumpAndSettle();
    expect(AppShellController.instance.current, AppTab.market);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(AppShellController.instance.current, AppTab.home);
    expect(find.text('MARKET'), findsNothing);
    expect(find.text('List View'), findsOneWidget);
  });

  testWidgets('logging out and back in starts on Home again', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell(initialTab: AppTab.profile)));
    await tester.pumpAndSettle();
    expect(AppShellController.instance.current, AppTab.profile);

    // Logout replaces the whole stack, which disposes the shell.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(AppShellController.instance.hasShell, isFalse);
    expect(AppShellController.instance.current, AppTab.home);
  });
}
