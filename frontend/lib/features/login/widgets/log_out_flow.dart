import 'package:flutter/material.dart';

import '../../saved/providers/saved_listings_controller.dart';
import '../screens/login_page.dart';
import '../services/auth_service.dart';

/// Asks first, then ends the session and drops the whole navigator stack, so
/// no screen of the old account stays mounted behind the login page. Used by
/// Account settings and the explore menu.
Future<void> confirmAndLogOut(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again to make offers or message sellers.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !navigator.mounted) return;
  AuthService.logout();
  SavedListingsController.instance.clear();
  navigator.pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
}
