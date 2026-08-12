import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_listing_card.dart';
import '../../../shared/widgets/kubo_location_badge.dart';
import '../../../shared/widgets/kubo_placeholder_page.dart';
import '../../../shared/widgets/kubo_search_field.dart';
import '../../../shared/widgets/kubo_view_toggle_button.dart';
import '../../explore/screens/explore_page.dart';
import '../../market/screens/market_page.dart';
import '../../profile/screens/profile_page.dart';

/// Search results page with list/map toggles and synthetic listing results.
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
  bool _isListView = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SyntheticListingRecord> get _visibleListings {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return syntheticSearchResultListings;
    }

    return syntheticSearchResultListings
        .where(
          (listing) =>
              listing.title.toLowerCase().contains(query) ||
              listing.locationLabel.toLowerCase().contains(query) ||
              listing.sellerLabel.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  String get _locationLabel {
    final value = widget.initialLocationLabel.trim();
    return value.isEmpty ? 'Caybiga' : value;
  }

  void _submitSearch(String value) {
    setState(() {
      _searchController.text = value.trim();
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    });
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
          query: _searchController.text,
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
        builder:
            (_) => const KuboPlaceholderPage(
              title: 'Create Listing',
              message: 'The listing creation flow will live here.',
            ),
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
                          KuboLocationBadge(label: _locationLabel),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                      'Results for "${_searchController.text}"',
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
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Text(
                      'No search results yet for this term.',
                      style: TextStyle(
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.softBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      children: [
                        SizedBox(height: 8),
                        Icon(
                          Icons.map_outlined,
                          size: 72,
                          color: AppColors.green,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Map View',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Map results for the searched item will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
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
