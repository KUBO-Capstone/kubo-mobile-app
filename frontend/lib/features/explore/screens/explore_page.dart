import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/listing_service.dart';
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
  List<SyntheticListingRecord> _allListings = const <SyntheticListingRecord>[];

  /// Message shown when the listing fetch itself failed, so a network problem
  /// is not mistaken for an empty region.
  String? _loadError;

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
  }

  @override
  void dispose() {
    _listingService.dispose();
    super.dispose();
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

  // Returns only the listings that match the selected region filter.
  List<SyntheticListingRecord> get _visibleListings {
    if (_selectedRegionFilter == 'All') {
      return _allListings;
    }

    final selected = _normalizeRegion(_selectedRegionFilter);
    return _allListings
        .where((listing) => _normalizeRegion(listing.regionLabel) == selected)
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
                _ListingsGrid(
                  listings: _visibleListings,
                  loadError: _loadError,
                ),
              ] else ...[
                _ListingsMap(
                  listings: _visibleListings,
                  regionLabel: _locationLabel,
                  loadError: _loadError,
                ),
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

  /// Coordinate taken from the seller's address row.
  final LatLng point;

  /// Every listing sold from this address, within the active region filter.
  final List<SyntheticListingRecord> listings;
}

/// Map view that plots the region-filtered listings onto OpenStreetMap tiles.
class _ListingsMap extends StatefulWidget {
  const _ListingsMap({
    required this.listings,
    required this.regionLabel,
    this.loadError,
  });

  /// Listings already narrowed by the shared region filter chips.
  final List<SyntheticListingRecord> listings;

  /// Label describing the active region, used in the empty state.
  final String regionLabel;

  /// Set when the listing fetch failed, which is distinct from having no pins.
  final String? loadError;

  @override
  State<_ListingsMap> createState() => _ListingsMapState();
}

class _ListingsMapState extends State<_ListingsMap> {
  /// Drives the camera when the region filter changes the visible pins.
  final MapController _mapController = MapController();

  List<SyntheticListingRecord> get listings => widget.listings;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ListingsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // initialCenter and initialCameraFit only apply to the map's first build, so
    // a region change has to move the camera explicitly or the new pins land
    // off-screen. Compare by content: the parent rebuilds a fresh filtered list
    // every time, and refitting on identity would fight the user's panning.
    if (_signature(oldWidget.listings) != _signature(widget.listings)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitPins());
    }
  }

  /// Identifies which listings are on screen, ignoring list instance churn.
  String _signature(List<SyntheticListingRecord> records) =>
      records.map((record) => record.id).join(',');

  // Frames the current pins, zooming to the single farm when only one remains.
  void _fitPins() {
    if (!mounted) {
      return;
    }
    final pins = _pins;
    if (pins.isEmpty) {
      return;
    }
    if (pins.length == 1) {
      _mapController.move(pins.first.point, 12);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: pins.map((pin) => pin.point).toList(growable: false),
        padding: const EdgeInsets.all(48),
        maxZoom: 13,
      ),
    );
  }

  /// Groups listings by coordinate so one farm address renders one pin.
  List<_FarmPin> get _pins {
    final grouped = <String, _FarmPin>{};
    for (final listing in listings) {
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

  // Opens a sheet listing every product sold from the tapped farm location.
  void _showPinListings(BuildContext context, _FarmPin pin) {
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

  @override
  // Renders OSM tiles with one tappable pin per farm address in the active region.
  Widget build(BuildContext context) {
    final pins = _pins;
    final plotted = pins.fold<int>(0, (sum, pin) => sum + pin.listings.length);
    final missing = listings.length - plotted;

    if (pins.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 36),
        child: Center(
          child: Text(
            widget.loadError ??
                'No mapped listings in ${widget.regionLabel} yet. Sellers need '
                    'a saved address before they appear on the map.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gray, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 420,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pins.first.point,
                initialZoom: 11,
                // Frame every pin at once when the region spans several farms.
                initialCameraFit:
                    pins.length > 1
                        ? CameraFit.coordinates(
                          coordinates:
                              pins
                                  .map((pin) => pin.point)
                                  .toList(growable: false),
                          padding: const EdgeInsets.all(48),
                          maxZoom: 13,
                        )
                        : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Required by the OpenStreetMap tile usage policy.
                  userAgentPackageName: 'com.example.frontend',
                ),
                MarkerLayer(
                  markers: [
                    for (final pin in pins)
                      Marker(
                        point: pin.point,
                        width: 44,
                        height: 46,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _showPinListings(context, pin),
                          child: _FarmMarker(count: pin.listings.length),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          missing > 0
              ? '$plotted of ${listings.length} listings mapped, '
                  '$missing without a seller address'
              : '$plotted listing${plotted == 1 ? '' : 's'} across '
                  '${pins.length} farm${pins.length == 1 ? '' : 's'}',
          style: const TextStyle(color: AppColors.gray, fontSize: 13),
        ),
      ],
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
