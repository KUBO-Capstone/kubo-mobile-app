import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/bagsakan_service.dart';
import '../models/bagsakan_center.dart';
import '../models/location_result.dart';
import '../widgets/location_filter_sheet.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_icon_action_button.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/widgets/kubo_location_badge.dart';
import '../../../shared/widgets/kubo_placeholder_page.dart';
import '../../login/screens/login_page.dart';
import '../../market/screens/market_page.dart';
import '../../listing/screens/create_listing_page.dart';
import '../../notification/screens/notification_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../search/screens/search_page.dart';
import '../widgets/drawer_list_tile.dart';
import '../../../shared/widgets/kubo_view_toggle_button.dart';

/// Controls which explore presentation the user is currently viewing.
enum ExploreViewMode { list, map }

/// Which set of pins the map plots. Products is the default; bagsakan centers
/// are the alternate mode behind the warehouse toggle.
enum MapPinMode { products, centers }

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
  List<SyntheticListingRecord> _allListings = const <SyntheticListingRecord>[];
  List<BagsakanCenter> _allCenters = const <BagsakanCenter>[];

  /// Message shown when the listing fetch itself failed, so a network problem
  /// is not mistaken for an empty region.
  String? _loadError;

  /// Which pin set the map is showing. Products lead; bagsakan centers are the
  /// secondary mode behind the warehouse toggle.
  MapPinMode _pinMode = MapPinMode.products;

  /// Collapses the map to a strip so the cards below get the screen.
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
  }

  @override
  void dispose() {
    _listingService.dispose();
    _bagsakanService.dispose();
    super.dispose();
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
            currentLabel: _focusLocation?.label,
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
                _ListingsMap(
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
                  onToggleMinimized:
                      () => setState(() => _mapMinimized = !_mapMinimized),
                ),
                const SizedBox(height: 16),
                // The cards under the map mirror the pins, so switching modes
                // swaps produce cards for bagsakan center cards.
                if (_pinMode == MapPinMode.products)
                  _MapListingCards(
                    listings: _visibleListings,
                    loadError: _loadError,
                  )
                else
                  _BagsakanCards(centers: _visibleCenters),
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


/// One map pin representing a single farm address that may host several listings.
class _FarmPin {
  _FarmPin({required this.point, required this.listings});

  /// Coordinate taken from the farm address on the seller's farmer profile.
  final LatLng point;

  /// Every listing sold from this farm, within the active region filter.
  final List<SyntheticListingRecord> listings;
}

/// Map view that plots either farm listings or bagsakan centers onto
/// OpenStreetMap tiles, depending on the active pin mode.
class _ListingsMap extends StatefulWidget {
  const _ListingsMap({
    required this.listings,
    required this.centers,
    required this.pinMode,
    required this.minimized,
    required this.regionLabel,
    required this.onPinModeChanged,
    required this.onToggleMinimized,
    this.focusLocation,
    this.radiusKm = 25,
    this.loadError,
  });

  /// Centre of the active radius filter, drawn as a circle when set.
  final LocationResult? focusLocation;

  /// Radius in kilometres around [focusLocation].
  final double radiusKm;

  /// Listings already narrowed by the shared region filter chips.
  final List<SyntheticListingRecord> listings;

  /// Bagsakan centers narrowed by the same chips.
  final List<BagsakanCenter> centers;

  /// Which pin set to plot.
  final MapPinMode pinMode;

  /// Whether the map is collapsed to a strip so the cards get the screen.
  final bool minimized;

  /// Active region chip, or 'All' when the feed is unfiltered.
  final String regionLabel;

  /// Raised when the user taps the produce or warehouse toggle.
  final ValueChanged<MapPinMode> onPinModeChanged;

  /// Raised when the user taps the minimize/expand control.
  final VoidCallback onToggleMinimized;

  /// Set when the listing fetch failed, which is distinct from having no pins.
  final String? loadError;

  @override
  State<_ListingsMap> createState() => _ListingsMapState();
}

class _ListingsMapState extends State<_ListingsMap> {
  /// Drives the camera when filters or pin mode change the visible points.
  final MapController _mapController = MapController();

  /// Expanded and collapsed map heights, per the minimize control.
  static const _expandedHeight = 420.0;
  static const _minimizedHeight = 150.0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ListingsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // initialCenter and initialCameraFit only apply to the map's first build,
    // so a region or mode change has to move the camera explicitly or the new
    // pins land off-screen. Compare by content: the parent rebuilds a fresh
    // filtered list every time, and refitting on identity would fight panning.
    if (_signature(oldWidget) != _signature(widget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPoints());
    }
  }

  /// Identifies what is on screen, ignoring list instance churn.
  String _signature(_ListingsMap w) {
    final ids =
        w.pinMode == MapPinMode.products
            ? w.listings.map((record) => record.id)
            : w.centers.map((center) => center.id);
    final focus = w.focusLocation;
    final focusKey =
        focus == null ? 'none' : '${focus.latitude},${focus.longitude},${w.radiusKm}';
    return '${w.pinMode}:$focusKey:${ids.join(',')}';
  }

  /// Groups listings by coordinate so one farm address renders one pin.
  List<_FarmPin> get _farmPins {
    final grouped = <String, _FarmPin>{};
    for (final listing in widget.listings) {
      if (!listing.hasCoordinates) {
        continue;
      }
      final key = '${listing.latitude},${listing.longitude}';
      grouped
          .putIfAbsent(
            key,
            () => _FarmPin(
              point: LatLng(listing.latitude!, listing.longitude!),
              listings: <SyntheticListingRecord>[],
            ),
          )
          .listings
          .add(listing);
    }
    return grouped.values.toList(growable: false);
  }

  /// Centers that carry coordinates and can therefore be plotted.
  List<BagsakanCenter> get _plottableCenters =>
      widget.centers.where((center) => center.hasCoordinates).toList(growable: false);

  /// Every point currently on the map, whichever mode is active.
  List<LatLng> get _points =>
      widget.pinMode == MapPinMode.products
          ? _farmPins.map((pin) => pin.point).toList(growable: false)
          : _plottableCenters
              .map((center) => LatLng(center.latitude!, center.longitude!))
              .toList(growable: false);

  /// Points the camera should frame. With a radius active this is the circle's
  /// compass extremes rather than the centre: fitting the centre alone zooms
  /// past the circle, leaving the user no sense of how far the filter reaches.
  List<LatLng> get _cameraPoints {
    final focus = widget.focusLocation;
    if (focus == null) {
      return _points;
    }

    const distance = Distance();
    final centre = LatLng(focus.latitude, focus.longitude);
    final metres = widget.radiusKm * 1000;
    return <LatLng>[
      ..._points,
      for (final bearing in <double>[0, 90, 180, 270])
        distance.offset(centre, metres, bearing),
    ];
  }

  // Frames the current points, zooming in when only one remains.
  void _fitPoints() {
    if (!mounted) {
      return;
    }
    final points = _cameraPoints;
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 12);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(48),
        maxZoom: 13,
      ),
    );
  }

  // Opens a sheet listing every product sold from the tapped farm location.
  void _showFarmListings(BuildContext context, _FarmPin pin) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final first = pin.listings.first;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.locationLabel,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${first.sellerLabel} - ${pin.listings.length} listing'
                  '${pin.listings.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.gray, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pin.listings.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (_, index) {
                      final listing = pin.listings[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.title,
                              style: const TextStyle(
                                color: AppColors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            listing.price,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Opens a sheet describing the tapped bagsakan drop-off center.
  void _showCenterDetail(BuildContext context, BagsakanCenter center) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  center.name,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        center.addressLine.isEmpty
                            ? '${center.locationLabel}, ${center.regionLabel}'
                            : '${center.addressLine}, ${center.locationLabel}',
                        style: const TextStyle(
                          color: AppColors.gray,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// " in Region III", or empty while the unfiltered 'All' chip is selected.
  String get _regionSuffix =>
      widget.regionLabel == 'All' ? '' : ' in ${widget.regionLabel}';

  /// Empty-state copy that distinguishes a failed fetch from an empty region.
  String get _emptyMessage {
    if (widget.loadError != null && widget.pinMode == MapPinMode.products) {
      return widget.loadError!;
    }
    return widget.pinMode == MapPinMode.products
        ? 'No mapped listings$_regionSuffix yet. Sellers need a saved farm '
            'address before they appear on the map.'
        : 'No bagsakan centers$_regionSuffix yet.';
  }

  @override
  Widget build(BuildContext context) {
    final farmPins = _farmPins;
    final centers = _plottableCenters;
    final isProducts = widget.pinMode == MapPinMode.products;
    final hasPins = isProducts ? farmPins.isNotEmpty : centers.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: widget.minimized ? _minimizedHeight : _expandedHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      hasPins
                          ? FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter:
                                  _points.isEmpty
                                      ? const LatLng(12.8797, 121.7740)
                                      : _points.first,
                              initialZoom: 11,
                              // Frame every pin at once, widening to the radius
                              // circle when a distance filter is active.
                              initialCameraFit:
                                  _cameraPoints.length > 1
                                      ? CameraFit.coordinates(
                                        coordinates: _cameraPoints,
                                        padding: const EdgeInsets.all(48),
                                        maxZoom: 13,
                                      )
                                      : null,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                // Required by the OpenStreetMap tile usage policy.
                                userAgentPackageName: 'com.example.frontend',
                              ),
                              // Shows how far the distance filter reaches.
                              if (widget.focusLocation != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: LatLng(
                                        widget.focusLocation!.latitude,
                                        widget.focusLocation!.longitude,
                                      ),
                                      radius: widget.radiusKm * 1000,
                                      useRadiusInMeter: true,
                                      color: AppColors.green.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderColor: AppColors.green,
                                      borderStrokeWidth: 1.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  if (isProducts)
                                    for (final pin in farmPins)
                                      Marker(
                                        point: pin.point,
                                        width: 44,
                                        height: 46,
                                        alignment: Alignment.topCenter,
                                        child: GestureDetector(
                                          onTap:
                                              () => _showFarmListings(context, pin),
                                          child: _FarmMarker(
                                            count: pin.listings.length,
                                          ),
                                        ),
                                      )
                                  else
                                    for (final center in centers)
                                      Marker(
                                        point: LatLng(
                                          center.latitude!,
                                          center.longitude!,
                                        ),
                                        width: 44,
                                        height: 46,
                                        alignment: Alignment.topCenter,
                                        child: GestureDetector(
                                          onTap:
                                              () => _showCenterDetail(
                                                context,
                                                center,
                                              ),
                                          child: const _CenterMarker(),
                                        ),
                                      ),
                                ],
                              ),
                              const RichAttributionWidget(
                                attributions: [
                                  TextSourceAttribution(
                                    'OpenStreetMap contributors',
                                  ),
                                ],
                              ),
                            ],
                          )
                          : Container(
                            color: AppColors.softBackground,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _emptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.gray,
                                fontSize: 14,
                              ),
                            ),
                          ),
                ),

                // Pin-mode toggle: produce listings or bagsakan drop-off points.
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _MapModeButton(
                        icon: Icons.inventory_2_outlined,
                        tooltip: 'Show produce listings',
                        selected: isProducts,
                        onTap:
                            () => widget.onPinModeChanged(MapPinMode.products),
                      ),
                      const SizedBox(height: 8),
                      _MapModeButton(
                        icon: Icons.warehouse_outlined,
                        tooltip: 'Show bagsakan centers',
                        selected: !isProducts,
                        onTap: () => widget.onPinModeChanged(MapPinMode.centers),
                      ),
                    ],
                  ),
                ),

                // Minimize / expand control.
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: _MapModeButton(
                    icon:
                        widget.minimized
                            ? Icons.open_in_full
                            : Icons.close_fullscreen,
                    tooltip: widget.minimized ? 'Expand map' : 'Minimize map',
                    selected: false,
                    onTap: widget.onToggleMinimized,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasPins) ...[
          const SizedBox(height: 10),
          Text(
            isProducts
                ? _listingSummary(farmPins)
                : '${centers.length} bagsakan center'
                    '${centers.length == 1 ? '' : 's'}$_regionSuffix',
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
        ],
      ],
    );
  }

  /// Summary line that also calls out listings missing a farm address.
  String _listingSummary(List<_FarmPin> pins) {
    final plotted = pins.fold<int>(0, (sum, pin) => sum + pin.listings.length);
    final missing = widget.listings.length - plotted;
    if (missing > 0) {
      return '$plotted of ${widget.listings.length} listings mapped, '
          '$missing without a farm address';
    }
    return '$plotted listing${plotted == 1 ? '' : 's'} across '
        '${pins.length} farm${pins.length == 1 ? '' : 's'}';
  }
}

/// Small translucent square button used for the map overlay controls.
class _MapModeButton extends StatelessWidget {
  const _MapModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Highlights the button green while its mode is the active one.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? AppColors.green : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: selected ? AppColors.white : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// Green map pin showing how many listings sit at one farm address.
class _FarmMarker extends StatelessWidget {
  const _FarmMarker({required this.count});

  /// Number of listings grouped under this pin.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.arrow_drop_down, color: AppColors.green, size: 18),
      ],
    );
  }
}

/// Map pin marking a bagsakan drop-off center.
class _CenterMarker extends StatelessWidget {
  const _CenterMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.black,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.warehouse_outlined,
            size: 15,
            color: AppColors.white,
          ),
        ),
        const Icon(Icons.arrow_drop_down, color: AppColors.black, size: 18),
      ],
    );
  }
}

/// Produce rows shown under the map, mirroring the plotted product pins.
class _MapListingCards extends StatelessWidget {
  const _MapListingCards({required this.listings, this.loadError});

  final List<SyntheticListingRecord> listings;

  /// Set when the listing fetch failed, which is distinct from an empty region.
  final String? loadError;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Center(
          child: Text(
            loadError ?? 'No listings to show for this filter yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: listings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final listing = listings[index];
        return _MapCardShell(
          imagePath: listing.imageAssetPath,
          title: listing.title,
          subtitle: '${listing.price} | ${listing.locationLabel}',
          footer: listing.sellerLabel,
          footerIcon: Icons.storefront_outlined,
          trailing: const Icon(
            Icons.favorite_border,
            size: 20,
            color: AppColors.gray,
          ),
        );
      },
    );
  }
}

/// Bagsakan center rows shown under the map in center mode.
class _BagsakanCards extends StatelessWidget {
  const _BagsakanCards({required this.centers});

  final List<BagsakanCenter> centers;

  @override
  Widget build(BuildContext context) {
    if (centers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 24),
        child: Center(
          child: Text(
            'No bagsakan centers to show for this filter yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: centers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final center = centers[index];
        return _MapCardShell(
          imagePath: AppAssets.placeholderImage,
          title: center.name,
          subtitle: center.addressLine.isEmpty
              ? center.regionLabel
              : center.addressLine,
          footer: center.locationLabel,
          footerIcon: Icons.location_on_outlined,
        );
      },
    );
  }
}

/// Shared row layout for the cards listed under the map.
class _MapCardShell extends StatelessWidget {
  const _MapCardShell({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.footerIcon,
    this.trailing,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final String footer;
  final IconData footerIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 72,
              child:
                  imagePath.startsWith('http')
                      ? Image.network(imagePath, fit: BoxFit.cover)
                      : Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.gray, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(footerIcon, size: 15, color: AppColors.gray),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.gray,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
