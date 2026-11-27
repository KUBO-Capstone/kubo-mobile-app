import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/login/services/auth_service.dart';
import 'package:frontend/features/profile/screens/edit_profile_page.dart';
import 'package:frontend/features/profile/widgets/complete_profile_prompt.dart';
import 'package:frontend/shared/data/session_store.dart';

import 'support/fake_api.dart';

const title = 'Complete your profile first';

/// What an account made with Google starts with: no contact number or address.
Map<String, dynamic> googleAccount() => <String, dynamic>{
      'user_id': 7,
      'first_name': 'Juan',
      'last_name': 'Dela Cruz',
      'email': 'juan@gmail.com',
      'contact_number': '',
      'preferred_address_id': null,
    };

/// A screen with one button that asks to make an offer, and what it was told.
class _Host extends StatelessWidget {
  const _Host(this.results);

  final List<bool> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => results.add(ensureProfileComplete(context, toDo: 'make an offer')),
            child: const Text('Make Offer'),
          ),
        ),
      ),
    );
  }
}

Future<List<bool>> pumpHost(WidgetTester tester) async {
  final results = <bool>[];
  await tester.pumpWidget(MaterialApp(home: _Host(results)));
  return results;
}

Future<void> tapMakeOffer(WidgetTester tester) async {
  await tester.tap(find.text('Make Offer'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthService.store = MemorySessionStore();
    AuthService.currentUser = googleAccount();
  });

  tearDown(() => AuthService.currentUser = null);

  group('missingProfileDetails', () {
    test('lists what an account made with Google lacks', () {
      expect(AuthService.missingProfileDetails, ['contact number', 'address']);
    });

    test('names only what is still missing', () {
      AuthService.currentUser = {...googleAccount(), 'contact_number': '09171234567'};
      expect(AuthService.missingProfileDetails, ['address']);
      AuthService.currentUser = {...googleAccount(), 'contact_number': '   ', 'preferred_address_id': 3};
      expect(AuthService.missingProfileDetails, ['contact number']);
    });

    test('nothing for a complete account, or with nobody signed in', () {
      AuthService.currentUser = {...googleAccount(), 'contact_number': '09171234567', 'preferred_address_id': 3};
      expect(AuthService.missingProfileDetails, isEmpty);
      AuthService.currentUser = null;
      expect(AuthService.missingProfileDetails, isEmpty);
    });
  });

  testWidgets('a complete account goes ahead with no banner', (tester) async {
    AuthService.currentUser = {...googleAccount(), 'contact_number': '09171234567', 'preferred_address_id': 3};
    final results = await pumpHost(tester);
    await tapMakeOffer(tester);
    expect(results, [true]);
    expect(find.text(title), findsNothing);
  });

  testWidgets('an incomplete account is stopped, and the banner drops in from above the screen', (tester) async {
    final results = await pumpHost(tester);
    await tester.tap(find.text('Make Offer'));
    await tester.pump();
    expect(results, [false]);
    // First frame: still above the top edge.
    expect(tester.getBottomLeft(find.text(title)).dy, lessThan(0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text(title)).dy, greaterThan(0));
    expect(find.text('Add your contact number and address to make an offer. Buyers and sellers need them to arrange the handover.'),
        findsOneWidget);
    expect(find.text('Complete Profile'), findsOneWidget);
  });

  testWidgets('it slides back up by itself after 5 seconds', (tester) async {
    await pumpHost(tester);
    await tapMakeOffer(tester);

    // The countdown runs from when it appeared, drop-in included.
    final settled = tester.getTopLeft(find.text(title)).dy;
    await tester.pump(const Duration(milliseconds: 4000));
    expect(tester.getTopLeft(find.text(title)).dy, settled);

    // Past 5 seconds: it starts leaving, moving up rather than vanishing.
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text(title), findsOneWidget);
    expect(tester.getTopLeft(find.text(title)).dy, lessThan(settled));

    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('swiping it up removes it', (tester) async {
    await pumpHost(tester);
    await tapMakeOffer(tester);

    await tester.fling(find.text(title), const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('swiping it sideways removes it', (tester) async {
    await pumpHost(tester);
    await tapMakeOffer(tester);

    await tester.fling(find.text(title), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('a small drag that is let go springs back, and the countdown starts over', (tester) async {
    await pumpHost(tester);
    await tapMakeOffer(tester);
    await tester.pump(const Duration(seconds: 4));

    await tester.drag(find.text(title), const Offset(0, -15));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);

    // Past the original 5 seconds, still up: the countdown restarted.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(title), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
  });

  testWidgets('tapping again while it is up keeps one banner', (tester) async {
    final results = await pumpHost(tester);
    await tapMakeOffer(tester);
    await tapMakeOffer(tester);
    expect(results, [false, false]);
    expect(find.text(title), findsOneWidget);
  });

  testWidgets('Complete profile opens Edit Profile, and saving lets the offer through', (tester) async {
    final api = FakeApi({
      'GET /users/7/profile': (_) => {...googleAccount(), 'addresses': <Object>[]},
    });
    await api.run(() async {
      final results = await pumpHost(tester);
      await tapMakeOffer(tester);

      await tester.tap(find.text('Complete Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
      expect(find.text(title), findsNothing);

      // What Edit Profile hands back once the user saves.
      tester.state<NavigatorState>(find.byType(Navigator)).pop(
        <String, dynamic>{...googleAccount(), 'contact_number': '09171234567', 'preferred_address_id': 12},
      );
      await tester.pumpAndSettle();
      expect(AuthService.missingProfileDetails, isEmpty);

      await tapMakeOffer(tester);
      expect(results, [false, true]);
      expect(find.text(title), findsNothing);
    });
  });
}
