import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/widgets/kubo_search_field.dart';
import '../../../shared/widgets/kubo_section_header.dart';
import '../../../shared/widgets/kubo_skeleton.dart';
import '../../explore/screens/explore_page.dart';
import '../../shell/providers/app_shell_controller.dart';
import '../providers/search_page_controller.dart';
import 'search_results_page.dart';
import '../widgets/search_recent_search_tile.dart';
import '../widgets/search_suggestion_card.dart';
import '../widgets/search_suggestion_tile.dart';

/// Search tab. Before anything is typed it shows the searches made this
/// session and the produce most listed right now; while typing, a list of
/// suggestions that follows the text.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialLocationLabel = ExplorePage.defaultLocationLabel,
  });

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
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  late final StreamSubscription<AppTab> _reselected;
  late final StreamSubscription<void> _listingsChanged;

  @override
  void initState() {
    super.initState();
    _controller = SearchPageController();
    _controller.loadPopular();
    _searchController = TextEditingController();
    _searchController.addListener(_followTypedText);
    // Tapping Search again scrolls back up, then puts the cursor in the field.
    _reselected = AppShellController.instance.onReselect(
      AppTab.search,
      () => scrollToTopOr(_scroll, _searchFocus.requestFocus),
    );
    // What is popular follows the listings that are up.
    _listingsChanged = AppShellController.instance.listingsChanged.listen((_) => _controller.loadPopular());
  }

  @override
  void dispose() {
    _reselected.cancel();
    _listingsChanged.cancel();
    _scroll.dispose();
    _searchFocus.dispose();
    _searchController.removeListener(_followTypedText);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _followTypedText() => _controller.updateTypedQuery(_searchController.text);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: KuboSearchField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      hintText: 'Search produce, towns or sellers',
                      onSubmitted: (_) => _submitSearch(),
                      onClear: () => _searchController.clear(),
                    ),
                  ),
                ),
                if (_controller.isTyping)
                  ..._buildTypedSuggestions()
                else
                  ..._buildBrowse(),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            );
          },
        ),
      ),
    );
  }

  // While typing: search for exactly what is typed, the user's own matching
  // searches, then what the listings suggest.
  List<Widget> _buildTypedSuggestions() {
    final typed = _controller.typedQuery;
    final recent = _controller.matchingRecentSearches;
    final matches = _controller.freshMatches;

    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 10,
          child: Align(
            alignment: Alignment.bottomCenter,
            // Fetching is quick; a thin bar says the list is still filling
            // without moving the rows under the user's thumb.
            child: _controller.isLoadingMatches
                ? const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.green,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
        ),
      ),
      SliverList.list(
        children: [
          SearchSuggestionTile(
            icon: Icons.search,
            text: 'Search for "$typed"',
            semanticLabel: 'Search for $typed',
            onTap: _submitSearch,
          ),
          for (final search in recent)
            SearchSuggestionTile(
              icon: Icons.history,
              text: search,
              typed: typed,
              onTap: () => _searchAndOpen(search),
            ),
          for (final suggestion in matches)
            SearchSuggestionTile(
              icon: switch (suggestion.type) {
                SuggestionType.listing => Icons.search,
                SuggestionType.place => Icons.location_on_outlined,
                SuggestionType.seller => Icons.storefront_outlined,
              },
              text: suggestion.text,
              typed: typed,
              note: switch (suggestion.type) {
                SuggestionType.listing =>
                  suggestion.listingCount > 1 ? '${suggestion.listingCount} listings' : null,
                SuggestionType.place => 'Town',
                SuggestionType.seller => 'Seller',
              },
              onTap: () => _searchAndOpen(suggestion.text),
            ),
        ],
      ),
    ];
  }

  // Nothing typed: recent searches, then what is popular.
  List<Widget> _buildBrowse() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KuboSectionHeader(
                title: 'Recent Searches',
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
              const KuboSectionHeader(title: 'Search Suggestions'),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      _buildPopular(),
    ];
  }

  Widget _buildPopular() {
    final popular = _controller.popular;
    if (_controller.isLoadingPopular && popular.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: ListingGridSkeleton.sliver(itemCount: 4),
      );
    }
    if (popular.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _controller.popularFailed
                    ? 'Could not load suggestions. Check your connection and try again.'
                    : 'Suggestions will appear here once growers post listings.',
                style: const TextStyle(color: AppColors.gray, fontSize: 14, height: 1.45),
              ),
              if (_controller.popularFailed)
                TextButton(
                  onPressed: _controller.loadPopular,
                  style: TextButton.styleFrom(foregroundColor: AppColors.green),
                  child: const Text('Try Again'),
                ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.84,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final suggestion = popular[index];
          return SearchSuggestionCard(
            suggestion: suggestion,
            onTap: () => _searchAndOpen(suggestion.text),
          );
        }, childCount: popular.length),
      ),
    );
  }
}
