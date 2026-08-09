import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../models/explore_listing.dart';
import '../widgets/explore_listing_card.dart';
import '../widgets/explore_section_page.dart';
import '../../login/screens/login_page.dart';
import '../widgets/drawer_list_tile.dart';

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
  static final List<ExploreListing> _allListings =
      List<ExploreListing>.unmodifiable(
        List<ExploreListing>.generate(10, (index) {
          const titles = <String>[
            'Fresh harvested tomatoes bundle',
            'Organic eggplant basket',
            'Sweet mango harvest box',
            'Leafy greens weekly pack',
            'Farm eggs tray set',
            'Red onion kilo pack',
            'Coconut vinegar set',
            'Native rice premium sack',
            'Banana blossoms harvest',
            'Seasonal vegetable mix',
          ];
          const locations = <String>[
            'Caloocan',
            'Bulacan',
            'Pampanga',
            'Laguna',
            'Rizal',
            'Quezon',
            'Cavite',
            'Batangas',
            'Nueva Ecija',
            'Bataan',
          ];
          const regions = <String>[
            'NCR',
            'Region III',
            'Region III',
            'Region IV-A',
            'NCR',
            'Region IV-A',
            'Region IV-A',
            'Region IV-A',
            'Region III',
            'Region III',
          ];

          final price = 120 + (index * 35);

          return ExploreListing(
            id: 'listing-$index',
            title: titles[index],
            price: 'PHP ${price.toStringAsFixed(0)}',
            locationLabel: locations[index],
            regionLabel: regions[index],
            sellerLabel: 'Kubo Grower ${index + 1}',
            imageAssetPath: AppAssets.placeholderImage,
          );
        }),
      );

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
  List<ExploreListing> get _visibleListings {
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

    final target = _TemplateNavPage(tabIndex: index);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => target));
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
          _AppBarActionButton(
            assetPath: AppIcons.bellNotification,
            onTap:
                () => _openSection(
                  context,
                  'Notifications',
                  'Notifications will appear here.',
                ),
          ),
          const SizedBox(width: 8),
          _AppBarActionButton(
            assetPath: AppIcons.heartSaved,
            onTap:
                () => _openSection(
                  context,
                  'Saved',
                  'Your saved listings will appear here.',
                ),
          ),
          const SizedBox(width: 8),
          _AppBarActionButton(
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
                _ViewToggleButton(
                  assetPath: AppIcons.listView,
                  label: 'List View',
                  selected: _viewMode == ExploreViewMode.list,
                  onTap: () => setState(() => _viewMode = ExploreViewMode.list),
                ),
                const SizedBox(width: 14),
                _ViewToggleButton(
                  assetPath: AppIcons.locationDot,
                  label: 'Map View',
                  selected: _viewMode == ExploreViewMode.map,
                  onTap: () => setState(() => _viewMode = ExploreViewMode.map),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSvgIcon(
                      assetPath: AppIcons.locationDot,
                      size: 16,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _locationLabel,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: const _ExploreDrawer(),
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

      bottomNavigationBar: _ExploreBottomNavBar(
        currentIndex: _currentBottomNavIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  // Opens one of the placeholder explore sections as a separate page.
  void _openSection(BuildContext context, String title, String message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreSectionPage(title: title, message: message),
      ),
    );
  }
}

/// Small icon action button used in the app bar trailing actions.
class _AppBarActionButton extends StatelessWidget {
  const _AppBarActionButton({required this.assetPath, required this.onTap});

  final String assetPath;
  final VoidCallback onTap;

  @override
  // Renders an icon button with a white circular background and SVG content.
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AppSvgIcon(
            assetPath: assetPath,
            size: 20,
            color: AppColors.black,
          ),
        ),
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
                  decoration: BoxDecoration(color: AppColors.softBackground),
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

              const SizedBox(height: 16), // gap before list items and header (Explore Menu)

              DrawerListTile(title: 'Market', iconPath: AppIcons.chartLine),          
              DrawerListTile(title: 'Saved', iconPath: AppIcons.heartSaved),
              DrawerListTile(title: 'Notification', iconPath: AppIcons.bellNotification),
              DrawerListTile(title: 'Help and Guide', iconPath: AppIcons.helpGuide),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Empty template pages used for bottom tabs while flows are pending.
class _TemplateNavPage extends StatelessWidget {
  const _TemplateNavPage({required this.tabIndex});

  /// Bottom navigation index this placeholder page represents.
  final int tabIndex;

  String get _title {
    switch (tabIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Search';
      case 2:
        return 'Add';
      case 3:
        return 'Market';
      case 4:
        return 'Profile';
      default:
        return 'Page';
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == tabIndex) {
      return;
    }

    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const ExplorePage()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _TemplateNavPage(tabIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              splashRadius: 22,
              icon: const AppSvgIcon(
                assetPath: AppIcons.barsMore,
                size: 24,
                color: AppColors.black,
              ),
            );
          },
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      drawer: const _ExploreDrawer(),
      body: Center(
        child: Text(
          '$_title template page',
          style: const TextStyle(
            color: AppColors.gray,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBar: _ExploreBottomNavBar(
        currentIndex: tabIndex,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
    );
  }
}

/// Shared bottom nav that uses asset icons and active indicator dots.
class _ExploreBottomNavBar extends StatelessWidget {
  const _ExploreBottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_BottomNavItemData> _items = <_BottomNavItemData>[
    _BottomNavItemData(label: 'Home', assetPath: AppIcons.home),
    _BottomNavItemData(label: 'Search', assetPath: AppIcons.search),
    _BottomNavItemData(
      label: 'Add',
      assetPath: AppIcons.squarePlus,
      alwaysGreen: true,
    ),
    _BottomNavItemData(label: 'Market', assetPath: AppIcons.chartLine),
    _BottomNavItemData(label: 'Profile', assetPath: AppIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: List<Widget>.generate(_items.length, (index) {
            final item = _items[index];
            final isActive = currentIndex == index;
            final color =
                item.alwaysGreen || isActive ? AppColors.green : AppColors.gray;

            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSvgIcon(
                        assetPath: item.assetPath,
                        size: 19,
                        color: color,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              isActive ? AppColors.green : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomNavItemData {
  const _BottomNavItemData({
    required this.label,
    required this.assetPath,
    this.alwaysGreen = false,
  });

  final String label;
  final String assetPath;
  final bool alwaysGreen;
}

/// Text-and-icon toggle that switches the explore content between list and map modes.
class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  // Draws the selected state with brand green and an underline indicator.
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.gray;

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(assetPath: assetPath, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            width: 62,
            height: 2,
            color: selected ? AppColors.green : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

/// Responsive grid that shows the currently visible listing cards.
class _ListingsGrid extends StatelessWidget {
  const _ListingsGrid({required this.listings});

  final List<ExploreListing> listings;

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
        return ExploreListingCard(listing: listings[index]);
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
