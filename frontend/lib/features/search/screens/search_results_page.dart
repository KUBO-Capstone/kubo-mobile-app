import 'package:flutter/material.dart';

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
    this.initialLocationLabel = 'Caybiga',
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

  String get _locationLabel {
    final value = widget.initialLocationLabel.trim();
    return value.isEmpty ? 'Caybiga' : value;
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
          initialLocationLabel: widget.initialLocationLabel,
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
          initialLocationLabel: widget.initialLocationLabel,
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
    final listings = _listings;

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
                          KuboLocationBadge(label: _locationLabel),
                        ],
                      ),
                    ),

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
