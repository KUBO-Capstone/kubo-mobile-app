import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_placeholder_page.dart';
import '../../explore/screens/explore_page.dart';
import '../../market/screens/market_page.dart';
import '../../search/screens/search_page.dart';

/// Profile tab placeholder that will later host account settings and identity.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.initialLocationLabel = 'Caybiga'});

  /// Route name used by the app shell when opening the profile tab.
  static const routeName = '/profile';

  /// Current account location carried from onboarding and the home tab.
  final String initialLocationLabel;

  void _navigateToTab(BuildContext context, int index) {
    if (index == 3) {
      return;
    }

    Widget destination;
    switch (index) {
      case 0:
        destination = ExplorePage(initialLocationLabel: initialLocationLabel);
      case 1:
        destination = SearchPage(initialLocationLabel: initialLocationLabel);
      case 2:
        destination = MarketPage(initialLocationLabel: initialLocationLabel);
      default:
        destination = ProfilePage(initialLocationLabel: initialLocationLabel);
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _openCreateListing(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => const KuboPlaceholderPage(
              title: 'Create Listing',
              message: 'The listing creation flow will live here.',
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: const KuboPlaceholderContent(
        title: 'Profile',
        message: 'Profile settings and account details will appear here.',
      ),
      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: 3,
        onDestinationSelected: (index) => _navigateToTab(context, index),
        onCenterActionPressed: () => _openCreateListing(context),
      ),
    );
  }
}
