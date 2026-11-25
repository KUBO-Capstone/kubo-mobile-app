import 'package:flutter/material.dart';

import '../../../shared/widgets/kubo_top_banner.dart';
import '../../login/services/auth_service.dart';
import '../screens/edit_profile_page.dart';

/// Lets [toDo] go ahead ("make an offer", "create a listing") only once the
/// signed-in account has a contact number and an address, which the other
/// side of a deal needs. Otherwise says what is missing in a banner from the
/// top of the screen, with a button to Edit Profile, and returns false.
bool ensureProfileComplete(BuildContext context, {required String toDo}) {
  final missing = AuthService.missingProfileDetails;
  if (missing.isEmpty) return true;

  // Taken now: the screen that asked may be gone by the time the button is
  // tapped, and Edit Profile opens over everything anyway.
  final navigator = Navigator.of(context, rootNavigator: true);
  KuboTopBanner.show(
    context,
    icon: Icons.person_outline,
    title: 'Complete your profile first',
    message: 'Add your ${missing.join(' and ')} to $toDo. Buyers and sellers need them to arrange the handover.',
    actionLabel: 'Complete profile',
    onAction: () => _openEditProfile(navigator),
  );
  return false;
}

Future<void> _openEditProfile(NavigatorState navigator) async {
  final user = AuthService.currentUser;
  if (user == null || !navigator.mounted) return;
  final updated = await navigator.push<Map<String, dynamic>>(
    MaterialPageRoute<Map<String, dynamic>>(builder: (_) => EditProfilePage(user: user)),
  );
  // The saved profile carries the new contact number and preferred address,
  // which is what lets the next offer or listing through.
  if (updated != null) AuthService.updateCurrentUser(updated);
}
