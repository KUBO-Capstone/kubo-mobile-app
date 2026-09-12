import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../explore/screens/explore_page.dart';
import '../../listing/screens/create_listing_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../search/screens/search_page.dart';
import '../widgets/offers_view.dart';

/// Market tab: the signed-in user's offers, received and sent.
class MarketPage extends StatelessWidget {
  const MarketPage({super.key, this.initialLocationLabel = 'Caybiga'});

  /// Route name used by the app shell when opening the market tab.
  static const routeName = '/market';

  /// Current account location carried from onboarding and the home tab.
  final String initialLocationLabel;

  void _navigateToTab(BuildContext context, int index) {
    if (index == 2) {
      return;
    }

    Widget destination;
    switch (index) {
      case 0:
        destination = ExplorePage(initialLocationLabel: initialLocationLabel);
      case 1:
        destination = SearchPage(initialLocationLabel: initialLocationLabel);
      case 3:
        destination = ProfilePage(initialLocationLabel: initialLocationLabel);
      default:
        destination = MarketPage(initialLocationLabel: initialLocationLabel);
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _openCreateListing(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => const CreateListingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: const OffersView(),
      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: 2,
        onDestinationSelected: (index) => _navigateToTab(context, index),
        onCenterActionPressed: () => _openCreateListing(context),
      ),
    );
  }
}
