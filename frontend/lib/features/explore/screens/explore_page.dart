import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/bagsakan_service.dart';
import '../models/bagsakan_center.dart';
import '../models/location_result.dart';
import '../widgets/listings_map.dart';
import '../widgets/location_filter_sheet.dart';
import '../widgets/map_result_cards.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_icon_action_button.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/widgets/kubo_location_badge.dart';
import '../../chat/providers/messages_controller.dart';
import '../../chat/screens/messages_page.dart';
import '../../market/screens/market_page.dart';
import '../../listing/screens/create_listing_page.dart';
import '../../notification/screens/notification_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../saved/providers/saved_listings_controller.dart';
import '../../saved/screens/saved_listings_page.dart';
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

  final ListingService _listingService = ListingService();
  final BagsakanService _bagsakanService = BagsakanService();

  /// Inbox summary for the unread badge on the chat icon. Loaded on entry and
  /// again whenever the inbox pops back to this screen.
  final MessagesController _messages = MessagesController();
  List<SyntheticListingRecord> _allListings = const <SyntheticListingRecord>[];
  List<BagsakanCenter> _allCenters = const <BagsakanCenter>[];

  /// Message shown when the listing fetch itself failed, so a network problem
  /// is not mistaken for an empty region.
  String? _loadError;

  /// Which pin set the map is showing. Products lead; bagsakan centers are the
  /// secondary mode behind the warehouse toggle.
  MapPinMode _pinMode = MapPinMode.products;

  /// Collapses the map to a strip so the cards below get the screen. Driven
  /// only by the map's corner control; scrolling leaves the map alone.
  bool _mapMinimized = false;

  /// Point the radius filter is measured from, set via the location sheet.
  /// Null means no distance filter is active and only the region chips apply.
  LocationResult? _focusLocation;

  /// Radius in kilometres around [_focusLocation].
  double _radiusKm = 25;

  /// Locations picked earlier this session, most recent first.
  final List<LocationResult> _recentLocations = <LocationResult>[];

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
    _loadListings();
    _loadCenters();
    // Explore is the landing screen after login, so this is where the hearts
    // on every grid get their initial state (and re-key on a different user).
    SavedListingsController.instance.loadIds();
    _messages.load();
  }

  @override
  void dispose() {
    _listingService.dispose();
    _bagsakanService.dispose();
    _messages.dispose();
    super.dispose();
  }

  // Collapses or restores the map from the control in its corner.
  void _toggleMapMinimized() {
    setState(() => _mapMinimized = !_mapMinimized);
  }

  Future<void> _loadCenters() async {
    try {
      final centers = await _bagsakanService.fetchCenters();
      if (mounted) setState(() => _allCenters = centers);
    } catch (error) {
      // A center fetch failure only empties the secondary map mode, so it does
      // not clear the listings or claim the whole screen failed.
      debugPrint('Bagsakan center fetch failed: $error');
      if (mounted) setState(() => _allCenters = const <BagsakanCenter>[]);
    }
  }

  Future<void> _loadListings() async {
    try {
      final listings = await _listingService.fetchListings();
      if (mounted) {
        setState(() {
          _allListings = listings;
          _loadError = null;
        });
      }
    } catch (error) {
      debugPrint('Explore listing fetch failed: $error');
      if (mounted) {
        setState(() {
          _allListings = const <SyntheticListingRecord>[];
          _loadError = 'Could not reach the Kubo server. Pull to retry.';
        });
      }
    }
  }

  // Trims a region label down to the part the filter chips use.
  //
  // Seed data stores "Region III" while addresses saved through the app come
  // from philippines_rpcmb as "Region III - Central Luzon". Without this both
  // views would silently drop every seller who registered in the app.
  static String _normalizeRegion(String label) {
    final separatorIndex = label.indexOf(' - ');
    final trimmed =
        separatorIndex == -1 ? label : label.substring(0, separatorIndex);
    return trimmed.trim().toUpperCase();
  }

  // True when a point falls inside the active radius. The radius sits
  // alongside the region chips rather than replacing them, so both narrow the
  // same feed and a point must satisfy each active filter.
  bool _withinRadius(double? latitude, double? longitude) {
    final focus = _focusLocation;
    if (focus == null) {
      return true;
    }
    if (latitude == null || longitude == null) {
      // Without coordinates there is no way to prove a record is in range, so
      // a distance filter necessarily hides it.
      return false;
    }
    final km = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(focus.latitude, focus.longitude),
      LatLng(latitude, longitude),
    );
    return km <= _radiusKm;
  }

  bool _matchesRegion(String regionLabel) {
    if (_selectedRegionFilter == 'All') {
      return true;
    }
    return _normalizeRegion(regionLabel) ==
        _normalizeRegion(_selectedRegionFilter);
  }

  // Returns the listings passing both the region chip and the radius filter.
  List<SyntheticListingRecord> get _visibleListings {
    if (_selectedRegionFilter == 'All' && _focusLocation == null) {
      return _allListings;
    }

    return _allListings
        .where(
          (listing) =>
              _matchesRegion(listing.regionLabel) &&
              _withinRadius(listing.latitude, listing.longitude),
        )
        .toList(growable: false);
  }

  // Bagsakan centers narrowed by the same two filters as the listings.
  List<BagsakanCenter> get _visibleCenters {
    if (_selectedRegionFilter == 'All' && _focusLocation == null) {
      return _allCenters;
    }

    return _allCenters
        .where(
          (center) =>
              _matchesRegion(center.regionLabel) &&
              _withinRadius(center.latitude, center.longitude),
        )
        .toList(growable: false);
  }

  // Opens the location sheet from the header badge and applies the result.
  Future<void> _openLocationSheet() async {
    final selection = await showModalBottomSheet<LocationFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => LocationFilterSheet(
            initialRadiusKm: _radiusKm,
            recentLocations: _recentLocations,
            initialLocation: _focusLocation,
          ),
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _focusLocation = selection.location;
      _radiusKm = selection.radiusKm;
      _accountLocationLabel = selection.location.label;
      _recentLocations
        ..removeWhere((entry) => entry == selection.location)
        ..insert(0, selection.location);
      if (_recentLocations.length > 5) {
        _recentLocations.removeRange(5, _recentLocations.length);
      }
    });
  }

  // Clears the distance filter, leaving the region chips in charge.
  void _clearRadius() {
    setState(() => _focusLocation = null);
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
                () => Navigator.of(context).pushNamed(SavedListingsPage.routeName),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _messages,
            builder: (context, _) => KuboIconActionButton(
              assetPath: AppIcons.chat,
              badgeCount: _messages.unreadThreadCount,
              onTap: () async {
                await Navigator.of(context).pushNamed(MessagesPage.routeName);
                // Threads opened from the inbox were marked read; recount.
                _messages.load();
              },
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
                // Tapping the badge is how the wireframe opens the location
                // and radius picker.
                InkWell(
                  onTap: _openLocationSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: KuboLocationBadge(label: _locationLabel),
                  ),
                ),
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
              // The radius filter stacks on top of the region chips, so show
              // it as its own dismissible chip rather than folding it in.
              if (_focusLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: const Icon(
                        Icons.my_location,
                        size: 16,
                        color: AppColors.green,
                      ),
                      label: Text(
                        'Within ${_radiusKm.toStringAsFixed(0)} km of '
                        '${_focusLocation!.label}',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppColors.softBackground,
                      side: const BorderSide(color: AppColors.border),
                      onDeleted: _clearRadius,
                      onPressed: _openLocationSheet,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (_viewMode == ExploreViewMode.list) ...[
                _ListingsGrid(
                  listings: _visibleListings,
                  loadError: _loadError,
                ),
              ] else ...[
                ListingsMap(
                  listings: _visibleListings,
                  centers: _visibleCenters,
                  pinMode: _pinMode,
                  minimized: _mapMinimized,
                  regionLabel: _selectedRegionFilter,
                  focusLocation: _focusLocation,
                  radiusKm: _radiusKm,
                  loadError: _loadError,
                  onPinModeChanged:
                      (mode) => setState(() => _pinMode = mode),
                  onToggleMinimized: _toggleMapMinimized,
                ),
                const SizedBox(height: 16),
                // The cards under the map mirror the pins, so switching modes
                // swaps produce cards for bagsakan center cards.
                if (_pinMode == MapPinMode.products)
                  MapListingCards(
                    listings: _visibleListings,
                    loadError: _loadError,
                  )
                else
                  BagsakanCards(centers: _visibleCenters),
              ],
            ],
          ),
        ),
      ),

      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onDestinationSelected: _onBottomNavTap,
        onCenterActionPressed: () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateListingPage()));
        },
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
              DrawerListTile(
                title: 'Saved',
                iconPath: AppIcons.heartSaved,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(SavedListingsPage.routeName);
                },
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid that shows the currently visible listing cards.
class _ListingsGrid extends StatelessWidget {
  const _ListingsGrid({required this.listings, this.loadError});

  final List<SyntheticListingRecord> listings;

  /// Set when the fetch failed, which is a different state from no matches.
  final String? loadError;

  @override
  // Shows a no-results message when filtering leaves the grid empty.
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Center(
          child: Text(
            loadError ?? 'No listings available for this region yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray, fontSize: 14),
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
