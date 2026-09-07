import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_icon_action_button.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/widgets/kubo_location_badge.dart';
import '../../../shared/widgets/kubo_placeholder_page.dart';
import '../../login/screens/login_page.dart';
import '../../market/screens/market_page.dart';
import '../../notification/screens/notification_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../search/screens/search_page.dart';
import '../widgets/drawer_list_tile.dart';
import '../../../shared/widgets/kubo_view_toggle_button.dart';

/// Controls which explore presentation the user is currently viewing.
enum ExploreViewMode { list, map }

/// Main explore screen that shows filters, sample listings, and navigation shortcuts.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.initialLocationLabel = 'Caybiga'});

  /// Route name used by the app shell when opening the explore/home screen.
  static const routeName = '/explore';

  /// Location label passed in from onboarding so the header can show a real place.
  final String initialLocationLabel;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  // Region filters displayed as chips across the top of the listing feed.
  static const List<String> _regionFilters = <String>[
    'All',
    'Region I',
    'Region II',
    'Region III',
    'Region IV-A',
    'Region IV-B',
    'Region V',
    'Region VI',
    'Region VII',
    'Region VIII',
    'Region IX',
    'Region X',
    'Region XI',
    'Region XII',
    'Region XIII',
    'NCR',
    'CAR',
    'BARMM',
  ];

  // Demo listings used to populate the grid before real backend data is wired in.
  static final List<SyntheticListingRecord> _allListings =
      List<SyntheticListingRecord>.unmodifiable(syntheticExploreListings);

  /// Fallback or onboarding-provided location shown in the top-right badge.
  late String _accountLocationLabel;

  /// Currently selected region chip used to narrow the listing feed.
  String _selectedRegionFilter = 'All';

  /// Current content presentation mode for the explore body.
  ExploreViewMode _viewMode = ExploreViewMode.list;

  /// Active bottom-navigation index, with Home mapped to the real listings screen.
  final int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // Keep the onboarding location label usable even when the caller passes blank text.
    _accountLocationLabel =
        widget.initialLocationLabel.trim().isEmpty
            ? 'Caybiga'
            : widget.initialLocationLabel;
  }

  // Returns only the listings that match the selected region filter.
  List<SyntheticListingRecord> get _visibleListings {
    if (_selectedRegionFilter == 'All') {
      return _allListings;
    }

    return _allListings
        .where((listing) => listing.regionLabel == _selectedRegionFilter)
        .toList(growable: false);
  }

  // Chooses the label shown in the location badge at the top of the screen.
  String get _locationLabel {
    return _selectedRegionFilter == 'All'
        ? _accountLocationLabel
        : _selectedRegionFilter;
  }

  // Switches between root tabs and keeps only one tab screen on the stack.
  void _onBottomNavTap(int index) {
    if (index == _currentBottomNavIndex) {
      return;
    }

    Widget destination;
    switch (index) {
      case 1:
        destination = SearchPage(initialLocationLabel: _accountLocationLabel);
        break;
      case 2:
        destination = const MarketPage();
        break;
      case 3:
        destination = const ProfilePage();
        break;
      default:
        destination = ExplorePage(initialLocationLabel: _accountLocationLabel);
        break;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  // Builds the explore layout with filters, listing content, and the bottom nav.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 54,
        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              splashRadius: 22,
              icon: const AppSvgIcon(
                assetPath: AppIcons.barsMore,
                size: 22,
                color: AppColors.black,
              ),
            );
          },
        ),
        actions: [
          KuboIconActionButton(
            assetPath: AppIcons.bellNotification,
            onTap:
                () =>
                    Navigator.of(context).pushNamed(NotificationPage.routeName),
          ),
          const SizedBox(width: 8),
          KuboIconActionButton(
            assetPath: AppIcons.heartSaved,
            onTap:
                () => _openSection(
                  context,
                  'Saved',
                  'Your saved listings will appear here.',
                ),
          ),
          const SizedBox(width: 8),
          KuboIconActionButton(
            assetPath: AppIcons.chat,
            onTap:
                () => _openSection(
                  context,
                  'Messages',
                  'Your chats will appear here.',
                ),
          ),
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                KuboViewToggleButton(
                  assetPath: AppIcons.listView,
                  label: 'List View',
                  selected: _viewMode == ExploreViewMode.list,
                  onTap: () => setState(() => _viewMode = ExploreViewMode.list),
                ),
                const SizedBox(width: 14),
                KuboViewToggleButton(
                  assetPath: AppIcons.locationDot,
                  label: 'Map View',
                  selected: _viewMode == ExploreViewMode.map,
                  onTap: () => setState(() => _viewMode = ExploreViewMode.map),
                ),
                const Spacer(),
                KuboLocationBadge(label: _locationLabel),
              ],
            ),
          ),
        ),
      ),
      drawer: _ExploreDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _regionFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final region = _regionFilters[index];
                    final isSelected = region == _selectedRegionFilter;
                    return ChoiceChip(
                      label: Text(
                        region,
                        style: TextStyle(
                          color: isSelected ? AppColors.white : AppColors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.green,
                      backgroundColor: AppColors.white,
                      side: BorderSide(
                        color: isSelected ? AppColors.green : AppColors.border,
                        width: 1,
                      ),
                      shape: const StadiumBorder(),
                      onSelected: (_) {
                        setState(() {
                          _selectedRegionFilter = region;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_viewMode == ExploreViewMode.list) ...[
                _ListingsGrid(listings: _visibleListings),
              ] else ...[
                _MapPlaceholder(locationLabel: _locationLabel),
              ],
            ],
          ),
        ),
      ),

      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onDestinationSelected: _onBottomNavTap,
        onCenterActionPressed: () {
          _openSection(
            context,
            'Create Listing',
            'The listing creation flow will live here.',
          );
        },
      ),
    );
  }

  // Opens one of the placeholder explore sections as a separate page.
  void _openSection(BuildContext context, String title, String message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KuboPlaceholderPage(title: title, message: message),
      ),
    );
  }
}

/// Drawer template for explore menu entries.
class _ExploreDrawer extends StatelessWidget {
  const _ExploreDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            // Header and List Items
            children: [
              SizedBox(
                height: 50,
                child: DrawerHeader(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Explore Menu',
                      style: TextStyle(
                        color: AppColors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ), // gap before list items and header (Explore Menu)

              DrawerListTile(title: 'Market', iconPath: AppIcons.chartLine),
              DrawerListTile(title: 'Saved', iconPath: AppIcons.heartSaved),
              DrawerListTile(
                title: 'Notification',
                iconPath: AppIcons.bellNotification,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(NotificationPage.routeName);
                },
              ),
              DrawerListTile(
                title: 'Help and Guide',
                iconPath: AppIcons.helpGuide,
              ),
              DrawerListTile(title: 'Report', iconPath: AppIcons.flagReport),

              // Push logout button to the bottom of the drawer
              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                    // add more logout logic like deleting user session or clear user data
                  },
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid that shows the currently visible listing cards.
class _ListingsGrid extends StatelessWidget {
  const _ListingsGrid({required this.listings});

  final List<SyntheticListingRecord> listings;

  @override
  // Shows a no-results message when filtering leaves the grid empty.
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 36),
        child: Center(
          child: Text(
            'No listings available for this region yet.',
            style: TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
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
        return KuboListingCard(listing: listings[index]);
      },
    );
  }
}

/// Placeholder content that stands in for the future map experience.
class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.locationLabel});

  final String locationLabel;

  @override
  // Explains that map functionality will be introduced later and echoes the current location.
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.map_outlined, size: 72, color: AppColors.green),
          const SizedBox(height: 18),
          const Text(
            'Map View',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Map instructions will be added later. Current location: $locationLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
