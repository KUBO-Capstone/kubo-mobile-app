import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/data/message_service.dart';
import '../../chat/screens/chat_page.dart';
import '../../shell/providers/app_shell_controller.dart';
import '../../../shared/data/synthetic_records.dart';
import '../widgets/message_listing_picker.dart';
import '../../listing/widgets/manage_listing_sheet.dart';
import '../../login/screens/login_page.dart';
import '../../login/services/auth_service.dart';
import '../../orders/providers/orders_controller.dart';
import '../../orders/screens/order_page.dart';
import '../../orders/widgets/order_card.dart';
import '../../saved/providers/saved_listings_controller.dart';
import '../providers/profile_page_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../earnings/screens/lifetime_earnings_page.dart';
import '../../reviews/widgets/rating_summary_card.dart';
import '../../reviews/widgets/review_card.dart';
import '../widgets/profile_empty_state.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_section_tab_bar.dart';
import 'edit_profile_page.dart';
import 'account_settings_page.dart';

/// Profile tab that renders the own-account or visitor profile experience.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.initialLocationLabel = 'Caybiga',
    this.isOwnProfile = true,
    this.subject,
    this.isTabRoot = false,
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

  /// The Profile tab itself, under the shell's bar. Every other profile (a
  /// seller's, or your own reached from one of your listings) is pushed
  /// above the shell, gets a back button, and draws the bar itself.
  final bool isTabRoot;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfilePageController _controller;

  // Own profile only: purchases and sales for the Orders tab.
  final OrdersController _orders = OrdersController();

  final ScrollController _scroll = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  StreamSubscription<AppTab>? _reselected;
  bool _wasActiveTab = true;

  @override
  void initState() {
    super.initState();
    _listenToShell();
    _controller = ProfilePageController(
      isOwnProfile: widget.isOwnProfile,
      subject: widget.subject,
    );
    _controller.loadListings();
    _controller.loadProfile();
    _controller.loadReviews();
    if (widget.isOwnProfile) {
      SavedListingsController.instance.load();
      _orders.load();
      _controller.loadEarnings();
    }
  }

  Future<void> _openEarnings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LifetimeEarningsPage()),
    );
    if (!mounted) return;
    // A listing may have been posted from the earnings page.
    _controller.loadEarnings();
    _controller.loadListings();
  }

  @override
  void dispose() {
    _reselected?.cancel();
    if (widget.isTabRoot) AppShellController.instance.removeListener(_handleShellTabChanged);
    _scroll.dispose();
    _controller.dispose();
    _orders.dispose();
    super.dispose();
  }

  void _listenToShell() {
    if (!widget.isTabRoot) return;
    // Tapping Profile again scrolls back to the top, then refreshes.
    _reselected = AppShellController.instance.onReselect(
      AppTab.profile,
      () => scrollToTopOr(_scroll, () => _refreshKey.currentState?.show()),
    );
    AppShellController.instance.addListener(_handleShellTabChanged);
  }

  // Coming back to the Profile tab picks up listings posted and orders
  // placed since it was last open, the way a social app's profile does.
  void _handleShellTabChanged() {
    final isActive = AppShellController.instance.current == AppTab.profile;
    if (isActive && !_wasActiveTab) {
      _controller.loadProfile();
      _controller.loadListings();
      if (widget.isOwnProfile) _orders.load();
    }
    _wasActiveTab = isActive;
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _controller.loadProfile(),
      _controller.loadListings(),
      if (widget.isOwnProfile) SavedListingsController.instance.load(),
      if (widget.isOwnProfile) _orders.load(),
    ]);
  }

  Future<void> _openOrder(int orderId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => OrderPage(orderId: orderId)),
    );
    if (!mounted) return;
    // A cancelled order puts stock back on a listing, so reload both.
    if (changed == true) {
      _orders.load();
      _controller.loadListings();
    }
  }

  Future<void> _openCreateListing() async {
    final created = await AppShellController.instance.createListing(context);
    if (created != null && mounted) {
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
    AppShellController.instance.notifyListingsChanged();
  }

  Future<void> _openEditProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(builder: (_) => EditProfilePage(user: user)),
    );
    if (updated != null && mounted) await _controller.setProfile(updated);
  }

  Future<void> _openShare() async {
    final profile = _controller.profile;
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    final shareText = '${profile.displayName} on Kubo\n\n${profile.about}\n\nView this profile: https://kubo.app/profile/$userId';
    await Share.share(shareText, subject: '${profile.displayName} on Kubo');
  }

  Future<void> _openSettings() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => AccountSettingsPage(user: user, onLogout: _logout),
      ),
    );
    if (updated != null && mounted) await _controller.setProfile(updated);
  }

  void _followProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Followed profile')),
    );
  }

  // Chats belong to a listing, so messaging a seller means asking about one
  // of theirs: pick it (skipped when there is only one), then open the same
  // thread the listing page's Message button opens.
  Future<void> _messageProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _controller.profile.displayName;
    if (AuthService.currentUserId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Log in to message sellers.')));
      return;
    }
    if (_controller.listings.isEmpty) await _controller.loadListings();
    if (!mounted) return;
    final listings = _controller.listings
        .where((listing) => listing.productId != null && !listing.isSoldOut)
        .toList(growable: false);
    if (listings.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('$name has no listings to ask about yet.')));
      return;
    }
    final listing = listings.length == 1
        ? listings.first
        : await showMessageListingPicker(context, sellerName: name, listings: listings);
    if (listing == null || !mounted) return;
    final service = MessageService();
    try {
      final thread = await service.openConversation(productId: listing.productId!);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChatPage(conversationId: thread.id)),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      service.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(key: _refreshKey, color: AppColors.green, onRefresh: _refresh, child: AnimatedBuilder(
          animation: Listenable.merge([_controller, SavedListingsController.instance, _orders]),
          builder: (context, _) {
            return CustomScrollView(
              controller: _scroll,
              // Pull-to-refresh has to work even when the profile is short.
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                      // Every profile pushed above the shell (a seller's, or
                      // your own from one of your listings) needs a way back;
                      // the Profile tab itself never does.
                      if (!widget.isTabRoot && Navigator.of(context).canPop())
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Material(
                            color: AppColors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              tooltip: 'Back',
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
                          onChangePhoto: _openEditProfile,
                          onRatingTap: () => _controller.selectSection(ProfileSection.reviews),
                        ),
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 34)),
                if (widget.isOwnProfile && _controller.earnings != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: _EarningsBanner(
                        total: _controller.earnings!.totalEarned,
                        completedOrders: _controller.earnings!.completedOrders,
                        onTap: _openEarnings,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: ProfileSectionTabBar(
                    selectedSection: _controller.selectedSection,
                    showSavedTab: widget.isOwnProfile,
                    showOrdersTab: widget.isOwnProfile,
                    onSectionSelected: (section) {
                      if (!widget.isOwnProfile &&
                          (section == ProfileSection.saved || section == ProfileSection.orders)) {
                        return;
                      }
                      if (section == ProfileSection.orders) _orders.load();
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
        )),
      ),
      // The tab's own profile sits under the shell's bar. A pushed profile
      // draws the bar itself; its Profile item leads back to your own.
      bottomNavigationBar: widget.isTabRoot ? null : const KuboBottomNavigationBar.detached(),
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
      case ProfileSection.orders:
        return _buildOrdersSection();
    }
  }

  Widget _buildOrdersSection() {
    final orders = _orders.orders;
    final userId = AuthService.currentUserId ?? 0;
    if (_orders.isLoading && orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    final error = _orders.errorMessage;
    if (error != null && orders.isEmpty) {
      return ProfileEmptyState(
        title: 'Could not load orders',
        message: error,
        actionLabel: 'Retry',
        onActionPressed: _orders.load,
      );
    }
    if (orders.isEmpty) {
      return ProfileEmptyState(
        title: 'No orders yet',
        message: 'When an offer is accepted, arrange pickup or delivery from the chat and it shows up here.',
        actionLabel: 'Browse listings',
        onActionPressed: _navigateHomeToExplore,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        children: [
          for (final order in orders) ...[
            OrderCard(
              order: order,
              userId: userId,
              onTap: () => _openOrder(order.id),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
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
    if (!_controller.reviewsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    if (!_controller.hasAnyReviews) {
      return ProfileEmptyState(
        title: 'No reviews yet',
        message: widget.isOwnProfile
            ? 'After a completed order, buyers and sellers you deal with can rate you here.'
            : 'This profile has no reviews yet.',
        actionLabel: widget.isOwnProfile ? 'Share profile' : null,
        onActionPressed: widget.isOwnProfile ? _openShare : null,
      );
    }

    final reviews = _controller.reviews;
    final stars = _controller.starFilter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: RatingSummaryCard(summary: _controller.ratingSummary),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final filter in ReviewerFilter.values) ...[
                _FilterChoice(
                  label: switch (filter) {
                    ReviewerFilter.all => 'All',
                    ReviewerFilter.buyers => 'From buyers',
                    ReviewerFilter.sellers => 'From sellers',
                  },
                  selected: _controller.reviewerFilter == filter,
                  onTap: () => _controller.setReviewFilters(reviewer: filter),
                ),
                const SizedBox(width: 8),
              ],
              PopupMenuButton<int>(
                tooltip: 'Filter by stars',
                initialValue: stars ?? 0,
                onSelected: (value) => _controller.setReviewFilters(stars: () => value == 0 ? null : value),
                itemBuilder: (_) => [
                  const PopupMenuItem<int>(value: 0, child: Text('All stars')),
                  for (var star = 5; star >= 1; star--)
                    PopupMenuItem<int>(value: star, child: Text('$star star${star == 1 ? '' : 's'}')),
                ],
                child: _PillButton(label: stars == null ? '★ All stars' : '★ $stars', fontSize: 12),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<ReviewSort>(
                tooltip: 'Sort reviews',
                initialValue: _controller.reviewSort,
                onSelected: (sort) => _controller.setReviewFilters(sort: sort),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: ReviewSort.newest, child: Text('Newest')),
                  PopupMenuItem(value: ReviewSort.highest, child: Text('Highest rated')),
                  PopupMenuItem(value: ReviewSort.lowest, child: Text('Lowest rated')),
                ],
                child: _PillButton(
                  label: 'Sort: ${switch (_controller.reviewSort) {
                    ReviewSort.newest => 'Newest',
                    ReviewSort.highest => 'Highest',
                    ReviewSort.lowest => 'Lowest',
                  }}',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('No reviews match these filters.', style: TextStyle(color: AppColors.gray, fontSize: 13)),
          )
        else
          ...reviews.map((review) => ReviewCard(review: review)),
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
          if (_controller.profile.businessName.isNotEmpty)
            _DetailRow(
              icon: Icons.storefront_outlined,
              label: 'Business',
              value: _controller.profile.businessName,
            ),
          if (_controller.profile.businessType.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: _controller.profile.businessType,
            ),
          ],
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
          const SizedBox(height: 24),
          const Text(
            'Profile analytics',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnalyticsCard(
                  label: 'Followers',
                  value: _controller.profile.followersCount.toString(),
                  accent: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsCard(
                  label: 'Listings',
                  value: _controller.profile.listingCount.toString(),
                  accent: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnalyticsCard(
                  label: 'Rating',
                  value: _controller.ratingSummary.hasReviews
                      ? _controller.ratingSummary.average!.toStringAsFixed(1)
                      : '—',
                  accent: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsCard(
                  label: 'Reviews',
                  value: _controller.profile.reviewCount.toString(),
                  accent: AppColors.gray,
                ),
              ),
            ],
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
    AppShellController.instance.goTo(AppTab.home);
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

/// Pill-shaped label used as the face of the star / sort menus.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.fontSize,
  });

  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: AppColors.black, fontSize: fontSize, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.gray),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : AppColors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.green : AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Owner-only shortcut to Lifetime earnings, under the profile header.
class _EarningsBanner extends StatelessWidget {
  const _EarningsBanner({required this.total, required this.completedOrders, required this.onTap});

  final double total;
  final int completedOrders;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.green.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                child: const Icon(Icons.savings_outlined, color: AppColors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lifetime earnings', style: TextStyle(color: AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      formatPeso(total),
                      style: const TextStyle(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Text(
                completedOrders == 0 ? 'See details' : '$completedOrders sold',
                style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Icon(Icons.chevron_right, color: AppColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}