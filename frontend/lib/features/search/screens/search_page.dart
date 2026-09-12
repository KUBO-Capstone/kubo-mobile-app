import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_bottom_navigation_bar.dart';
import '../../../shared/widgets/kubo_search_field.dart';
import '../../../shared/widgets/kubo_section_header.dart';
import '../../explore/screens/explore_page.dart';
import '../../listing/screens/create_listing_page.dart';
import '../../market/screens/market_page.dart';
import '../../profile/screens/profile_page.dart';
import '../providers/search_page_controller.dart';
import 'search_results_page.dart';
import '../widgets/search_recent_search_tile.dart';
import '../widgets/search_suggestion_card.dart';

/// Search tab that shows query input, recent searches, and random suggestions.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialLocationLabel = 'Caybiga'});

  /// Route name used when the search page is registered in the app shell.
  static const routeName = '/search';

  /// Current account location carried from onboarding and the home tab.
  final String initialLocationLabel;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchPageController _controller;
  late final TextEditingController _searchController;

  void _handleSearchTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = SearchPageController();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    _controller.submitSearch(query);
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultsPage(
          query: query,
          initialLocationLabel: widget.initialLocationLabel,
        ),
      ),
    );
  }

  void _searchAndOpen(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _submitSearch();
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
        destination = SearchPage(
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
            (_) => const CreateListingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KuboSearchField(
                          controller: _searchController,
                          onSubmitted: (_) => _submitSearch(),
                          onClear: () => _searchController.clear(),
                        ),
                        const SizedBox(height: 18),
                        KuboSectionHeader(
                          title: 'Recent searches',
                          actionLabel: _controller.shouldShowRecentSearchToggle
                              ? _controller.recentSearchToggleLabel
                              : null,
                          onActionPressed: _controller.shouldShowRecentSearchToggle
                              ? _controller.toggleRecentSearchVisibility
                              : null,
                        ),
                        const SizedBox(height: 12),
                        if (!_controller.hasRecentSearches)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Your recent searches will appear here once you search for something.',
                              style: TextStyle(
                                color: AppColors.gray,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              ..._controller.visibleRecentSearches.map(
                                (query) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SearchRecentSearchTile(
                                    query: query,
                                    onTap: () => _searchAndOpen(query),
                                    onRemove:
                                        () => _controller.removeRecentSearch(
                                          query,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        const KuboSectionHeader(title: 'Search suggestions'),
                        const SizedBox(height: 12),
                        // if (_searchController.text.trim().isNotEmpty)
                        //   Text(
                        //     'Results for "${_searchController.text.trim()}"',
                        //     style: const TextStyle(
                        //       color: AppColors.black,
                        //       fontSize: 15,
                        //       fontWeight: FontWeight.w700,
                        //     ),
                        //   ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.84,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return SearchSuggestionCard(
                        suggestion: _controller.suggestions[index],
                        onTap: () => _searchAndOpen(
                          _controller.suggestions[index].name,
                        ),
                      );
                    }, childCount: _controller.suggestions.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            );
          },
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
