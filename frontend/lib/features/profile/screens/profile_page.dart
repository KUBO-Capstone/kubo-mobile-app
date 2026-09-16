import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/widgets/kubo_placeholder_page.dart';
import '../../explore/screens/explore_page.dart';
import '../../market/screens/market_page.dart';
import '../../search/screens/search_page.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../listing/screens/create_listing_page.dart';
import '../../listing/widgets/manage_listing_sheet.dart';
import '../../login/screens/login_page.dart';
import '../../login/services/auth_service.dart';
import '../../saved/providers/saved_listings_controller.dart';
import '../providers/profile_page_controller.dart';
import '../widgets/profile_empty_state.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_review_card.dart';
import '../widgets/profile_section_tab_bar.dart';

/// Profile tab that renders the own-account or visitor profile experience.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.initialLocationLabel = 'Caybiga',
    this.isOwnProfile = true,
    this.subject,
  });

  /// Opens the profile behind a listing's seller box. Falls back to the own
  /// profile when the viewer is looking at their own listing.
  factory ProfilePage.forSeller({
    required int sellerId,
    required String sellerName,
    String? locationLabel,
  }) {
    if (sellerId == AuthService.currentUserId) {
      return const ProfilePage();
    }
    return ProfilePage(
      isOwnProfile: false,
      subject: ProfileSubject(
        userId: sellerId,
        displayName: sellerName,
        locationLabel: locationLabel,
      ),
    );
  }

  /// Route name used by the app shell when opening the profile tab.
  static const routeName = '/profile';

  /// Current account location carried from onboarding and the home tab.
  final String initialLocationLabel;

  /// Whether this page should render as the signed-in user's own account.
  final bool isOwnProfile;

  /// Account to show when [isOwnProfile] is false.
  final ProfileSubject? subject;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfilePageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfilePageController(
      isOwnProfile: widget.isOwnProfile,
      subject: widget.subject,
    );
    _controller.loadListings();
    if (widget.isOwnProfile) SavedListingsController.instance.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (index == 3) {
      return;
    }

    Widget destination;
    switch (index) {
      case 0:
        destination = ExplorePage(
          initialLocationLabel: widget.initialLocationLabel,
        );
        break;
      case 1:
        destination = SearchPage(
          initialLocationLabel: widget.initialLocationLabel,
        );
        break;
      case 2:
        destination = MarketPage(
          initialLocationLabel: widget.initialLocationLabel,
        );
        break;
      default:
        destination = ProfilePage(
          initialLocationLabel: widget.initialLocationLabel,
          isOwnProfile: widget.isOwnProfile,
        );
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<SyntheticListingRecord>(
      MaterialPageRoute<SyntheticListingRecord>(
        builder: (_) => const CreateListingPage(),
      ),
    );
    if (created != null) {
      _controller.loadListings();
    }
  }

  // Seller actions on one of their own cards: edit, sold out, remove.
  Future<void> _manageListing(SyntheticListingRecord listing) async {
    final outcome = await showManageListingSheet(context, listing);
    if (outcome == null || !mounted) return;
    _controller.applyOutcome(listing.id, updated: outcome.listing);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.removed
              ? 'Listing removed.'
              : outcome.listing!.isSoldOut
                  ? 'Marked as sold out.'
                  : 'Listing updated.',
        ),
      ),
    );
    _controller.loadListings();
  }

  void _openEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const KuboPlaceholderPage(
          title: 'Edit Profile',
          message: 'The profile editor will live here.',
        ),
      ),
    );
  }

  void _openShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share profile action tapped')),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const KuboPlaceholderPage(
          title: 'Settings',
          message: 'The account settings screen will live here.',
        ),
      ),
    );
  }

  void _followProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Followed profile')),
    );
  }

  void _messageProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message action tapped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, SavedListingsController.instance]),
          builder: (context, _) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        height: 178,
                        width: double.infinity,
                        child: Image.asset(
                          AppAssets.coverLandscape,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Visitor profiles are pushed over a listing, so give
                      // them a way back that the own-profile tab never needs.
                      if (!widget.isOwnProfile && Navigator.of(context).canPop())
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Material(
                            color: AppColors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: AppColors.black,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 90),
                        child: ProfileHeaderCard(
                          profile: _controller.profile,
                          isOwnProfile: widget.isOwnProfile,
                          onEditProfile: _openEditProfile,
                          onShare: _openShare,
                          onSettings: _openSettings,
                          onFollow: _followProfile,
                          onMessage: _messageProfile,
                        ),
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 34)),
                SliverToBoxAdapter(
                  child: ProfileSectionTabBar(
                    selectedSection: _controller.selectedSection,
                    showSavedTab: widget.isOwnProfile,
                    onSectionSelected: (section) {
                      if (!widget.isOwnProfile && section == ProfileSection.saved) {
                        return;
                      }
                      _controller.selectSection(section);
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildSectionContent(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: 3,
        onDestinationSelected: _navigateToTab,
        onCenterActionPressed: _openCreateListing,
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_controller.selectedSection) {
      case ProfileSection.listings:
        return _buildListingsSection();
      case ProfileSection.reviews:
        return _buildReviewsSection();
      case ProfileSection.about:
        return _buildAboutSection();
      case ProfileSection.saved:
        return _buildSavedSection();
    }
  }

  Widget _buildListingsSection() {
    final listings = _controller.listings;
    if (listings.isEmpty) {
      return ProfileEmptyState(
        title: 'No listings yet',
        message: widget.isOwnProfile
            ? 'Your listings will appear here once you add them.'
            : 'This profile has not posted any listings yet.',
        actionLabel: widget.isOwnProfile ? 'Create listing' : null,
        onActionPressed: widget.isOwnProfile ? _openCreateListing : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: listings.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          final listing = listings[index];
          final canManage =
              widget.isOwnProfile &&
              listing.isOwnedBy(AuthService.currentUserId);
          return KuboListingCard(
            listing: listing,
            onManage: canManage ? () => _manageListing(listing) : null,
            onChanged: _controller.loadListings,
          );
        },
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = _controller.reviews;
    if (reviews.isEmpty) {
      return ProfileEmptyState(
        title: 'No reviews yet',
        message: widget.isOwnProfile
            ? 'Reviews from buyers and sellers will appear here once they start coming in.'
            : 'This profile has no reviews yet.',
        actionLabel: widget.isOwnProfile ? 'Share profile' : null,
        onActionPressed: widget.isOwnProfile ? _openShare : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Row(
            children: [
              Text(
                _controller.profile.reviewScore.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.star, color: AppColors.green, size: 14),
              const SizedBox(width: 10),
              Container(width: 1, height: 20, color: AppColors.border),
              const SizedBox(width: 10),
              Text(
                '${_controller.profile.reviewCount} reviews',
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _PillButton(
                label: 'Star ⭐ : All', 
                fontSize: 12,
                onTap: () {}
              ),
              const SizedBox(width: 8),
              _PillButton(
                label: 'Sort by: Newest', 
                fontSize: 12,
                onTap: () {}
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...reviews.map((review) => ProfileReviewCard(review: review)),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _controller.profile.about,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Account details',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date joined',
            value: _controller.profile.joinedLabel,
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.location_on_outlined,
            value: _controller.profile.locationLabel,
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.person_outline,
            value: _controller.profile.username,
          ),
          if (widget.isOwnProfile) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.black,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Ends the session and drops the whole navigator stack so no screen from
  // the old account stays mounted behind the login page.
  Future<void> _logout() async {
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
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    AuthService.logout();
    SavedListingsController.instance.clear();
    Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
  }

  Widget _buildSavedSection() {
    final savedListings = _controller.savedListings;
    if (savedListings.isEmpty) {
      return ProfileEmptyState(
        title: 'No saved listings yet',
        message: 'Saved items will appear here when you favorite a listing.',
        actionLabel: 'Browse listings',
        onActionPressed: _navigateHomeToExplore,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: savedListings.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          return KuboListingCard(listing: savedListings[index]);
        },
      ),
    );
  }

  void _navigateHomeToExplore() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ExplorePage(
          initialLocationLabel: widget.initialLocationLabel,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value, this.label});

  final IconData icon;
  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: AppColors.black),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label == null ? value : '$label | $value',
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label, 
    required this.onTap,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(
        label, 
        style: TextStyle(fontSize: fontSize)),
    );
  }
}