import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/kubo_search_field.dart';
import '../../../shared/widgets/kubo_section_header.dart';
import '../../explore/screens/explore_page.dart';
import '../../shell/providers/app_shell_controller.dart';
import '../providers/search_page_controller.dart';
import 'search_results_page.dart';
import '../widgets/search_recent_search_tile.dart';
import '../widgets/search_suggestion_card.dart';

/// Search tab that shows query input, recent searches, and random suggestions.
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

  @override
  void initState() {
    super.initState();
    _controller = SearchPageController();
    _searchController = TextEditingController();
    // Tapping Search again scrolls back up, then puts the cursor in the field.
    _reselected = AppShellController.instance.onReselect(
      AppTab.search,
      () => scrollToTopOr(_scroll, _searchFocus.requestFocus),
    );
  }

  @override
  void dispose() {
    _reselected.cancel();
    _scroll.dispose();
    _searchFocus.dispose();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KuboSearchField(
                          controller: _searchController,
                          focusNode: _searchFocus,
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
    );
  }
}
