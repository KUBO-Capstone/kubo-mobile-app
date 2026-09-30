import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/widgets/kubo_location_badge.dart';
import '../../../shared/widgets/kubo_search_field.dart';
import '../../../shared/widgets/kubo_view_toggle_button.dart';
import '../../explore/screens/explore_page.dart';
import '../../explore/models/location_result.dart';
import '../../explore/widgets/location_filter_sheet.dart';
import '../../explore/widgets/listings_map.dart';
import '../../explore/widgets/map_result_cards.dart';
import '../../market/screens/market_page.dart';
import '../../profile/screens/profile_page.dart';
import '../../listing/screens/create_listing_page.dart';

/// Search results page with list/map toggles over the matching listings.
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.query,
    this.initialLocationLabel = ExplorePage.defaultLocationLabel,
  });

  /// Route name used if the page is opened directly.
  static const routeName = '/search-results';

  /// Current search term shown in the search field.
  final String query;

  /// Current account location carried from onboarding and other tabs.
  final String initialLocationLabel;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late final TextEditingController _searchController;
  late final ListingService _listingService;
  List<SyntheticListingRecord> _listings = const <SyntheticListingRecord>[];

  /// Location and radius used to narrow the current search results.
  LocationResult? _focusLocation;
  double _radiusKm = 25;
  final List<LocationResult> _recentLocations = <LocationResult>[];
  late String _accountLocationLabel;

  /// Term the current results were fetched for; the field can be edited
  /// without changing this until the user submits.
  late String _query;

  /// Set when the fetch failed, so a network problem is not shown as
  /// "no results".
  String? _loadError;

  bool _isListView = true;

  /// Collapses the map to a strip, same control as the explore tab.
  bool _mapMinimized = false;

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _searchController = TextEditingController(text: widget.query);
    _listingService = ListingService();
    _accountLocationLabel =
        widget.initialLocationLabel.trim().isEmpty
            ? ExplorePage.defaultLocationLabel
            : widget.initialLocationLabel;
    _loadListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listingService.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    try {
      final listings = await _listingService.fetchListings(query: _query);
      if (mounted) {
        setState(() {
          _listings = listings;
          _loadError = null;
        });
      }
    } catch (error) {
      debugPrint('Search listing fetch failed: $error');
      if (mounted) {
        setState(() {
          _listings = const <SyntheticListingRecord>[];
          _loadError = 'Could not reach the Kubo server. Try again.';
        });
      }
    }
  }

  String get _locationLabel => _accountLocationLabel;

  bool _withinRadius(double? latitude, double? longitude) {
    final focus = _focusLocation;
    if (focus == null) {
      return true;
    }
    if (latitude == null || longitude == null) {
      return false;
    }
    final km = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(focus.latitude, focus.longitude),
      LatLng(latitude, longitude),
    );
    return km <= _radiusKm;
  }

  List<SyntheticListingRecord> get _visibleListings {
    if (_focusLocation == null) {
      return _listings;
    }
    return _listings
        .where((listing) => _withinRadius(listing.latitude, listing.longitude))
        .toList(growable: false);
  }

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

  void _clearLocationFilter() {
    setState(() {
      _focusLocation = null;
      _accountLocationLabel = 
        widget.initialLocationLabel.trim().isEmpty
                ? ExplorePage.defaultLocationLabel
                : widget.initialLocationLabel;
    });
  }

  // Re-runs the search for whatever is in the field.
  void _submitSearch(String value) {
    final query = value.trim();
    setState(() {
      _query = query;
      _searchController.text = query;
      _searchController.selection = TextSelection.collapsed(
        offset: query.length,
      );
    });
    _loadListings();
  }

  void _navigateToTab(int index) {
    if (index == 1) {
      return;
    }

    Widget destination;
    switch (index) {
      case 0:
        destination = ExplorePage(
          initialLocationLabel: _accountLocationLabel,
        );
        break;
      case 2:
        destination = const MarketPage();
        break;
      case 3:
        destination = const ProfilePage();
        break;
      default:
        destination = SearchResultsPage(
          query: _query,
          initialLocationLabel: _accountLocationLabel,
        );
        break;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _openCreateListing() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateListingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listings = _visibleListings;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            Navigator.pop(context);
                          }
                        ),
                        Expanded(
                          child: KuboSearchField(
                            controller: _searchController,
                            onSubmitted: _submitSearch,
                            onClear: () => _submitSearch(''),
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          KuboViewToggleButton(
                            assetPath: AppIcons.listView,
                            label: 'List View',
                            selected: _isListView,
                            onTap: () => setState(() => _isListView = true),
                          ),
                          const SizedBox(width: 14),
                          KuboViewToggleButton(
                            assetPath: AppIcons.locationDot,
                            label: 'Map View',
                            selected: !_isListView,
                            onTap: () => setState(() => _isListView = false),
                          ),
                          const Spacer(),
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

                    if (_focusLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 12),
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
                          onDeleted: _clearLocationFilter,
                          onPressed: _openLocationSheet,
                        ),
                      ),

                    if (_query.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Results for "$_query"',
                          style: const TextStyle(
                            color: AppColors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isListView)
              if (listings.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Text(
                      _loadError ?? 'No search results yet for this term.',
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return KuboListingCard(listing: listings[index]);
                    }, childCount: listings.length),
                  ),
                )
            else
              // Same map as the explore tab, minus the bagsakan toggle: a
              // produce search has nothing to say about drop-off centers.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListingsMap(
                        listings: listings,
                        focusLocation: _focusLocation,
                        radiusKm: _radiusKm,
                        minimized: _mapMinimized,
                        loadError: _loadError,
                        onToggleMinimized:
                            () => setState(() => _mapMinimized = !_mapMinimized),
                      ),
                      const SizedBox(height: 16),
                      MapListingCards(listings: listings, loadError: _loadError),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: KuboBottomNavigationBar(
        currentIndex: 1,
        onDestinationSelected: _navigateToTab,
        onCenterActionPressed: _openCreateListing,
      ),
    );
  }
}
