import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../profile/widgets/profile_empty_state.dart';
import '../providers/saved_listings_controller.dart';

/// The user's saved listings, pushed from the heart icon in the explore app
/// bar and the drawer's Saved tile. Same grid as explore, so unhearting a
/// card here drops it from the grid at once.
class SavedListingsPage extends StatefulWidget {
  const SavedListingsPage({super.key});

  static const routeName = '/saved';

  @override
  State<SavedListingsPage> createState() => _SavedListingsPageState();
}

class _SavedListingsPageState extends State<SavedListingsPage> {
  // App-wide instance, deliberately not disposed here.
  final SavedListingsController _controller = SavedListingsController.instance;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SAVED',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final listings = _controller.listings;
          if (_controller.isLoading && listings.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.green));
          }
          final error = _controller.errorMessage;
          if (error != null && listings.isEmpty) {
            return ProfileEmptyState(
              title: 'Could not load saved listings',
              message: error,
              actionLabel: 'Try again',
              onActionPressed: _controller.load,
            );
          }
          if (listings.isEmpty) {
            return ProfileEmptyState(
              title: 'No saved listings yet',
              message: 'Tap the heart on a listing to keep track of it here.',
              actionLabel: 'Browse listings',
              onActionPressed: () => Navigator.of(context).pop(),
            );
          }
          return RefreshIndicator(
            color: AppColors.green,
            onRefresh: _controller.load,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: listings.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) => KuboListingCard(listing: listings[index]),
            ),
          );
        },
      ),
    );
  }
}
