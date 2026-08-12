import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_assets.dart';

/// Immutable suggestion data shown in the search grid.
class SearchSuggestion {
  const SearchSuggestion({required this.name, required this.imageAssetPath});

  /// Display label shown under the suggestion image.
  final String name;

  /// Image asset rendered in the suggestion card.
  final String imageAssetPath;
}

/// Holds the transient state for the search page.
class SearchPageController extends ChangeNotifier {
  SearchPageController()
    : suggestions = List<SearchSuggestion>.unmodifiable(_buildSuggestions());

  static const int _recentSearchPreviewLimit = 4;

  /// Randomized suggestion list rendered under the search history.
  final List<SearchSuggestion> suggestions;

  final List<String> _recentSearches = <String>[];

  bool _showAllRecentSearches = false;

  /// Unmodifiable recent search history.
  List<String> get recentSearches => List<String>.unmodifiable(_recentSearches);

  /// Whether the full recent-search history is currently expanded.
  bool get showAllRecentSearches => _showAllRecentSearches;

  /// Whether the recent-search section should show the See more / See less control.
  bool get shouldShowRecentSearchToggle =>
      _recentSearches.length > _recentSearchPreviewLimit;

  /// Whether the search history contains any entries.
  bool get hasRecentSearches => _recentSearches.isNotEmpty;

  /// Recent searches currently visible based on the collapsed/expanded state.
  List<String> get visibleRecentSearches {
    if (_showAllRecentSearches ||
        _recentSearches.length <= _recentSearchPreviewLimit) {
      return recentSearches;
    }

    return List<String>.unmodifiable(
      _recentSearches.take(_recentSearchPreviewLimit),
    );
  }

  /// Label shown on the history toggle button.
  String get recentSearchToggleLabel =>
      _showAllRecentSearches ? 'See less' : 'See more';

  /// Stores a new search query at the top of the history list.
  void submitSearch(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }

    _recentSearches.removeWhere(
      (value) => value.toLowerCase() == normalizedQuery.toLowerCase(),
    );
    _recentSearches.insert(0, normalizedQuery);
    notifyListeners();
  }

  /// Removes one history item from the list.
  void removeRecentSearch(String query) {
    final removed = _recentSearches.remove(query);
    if (removed) {
      if (_recentSearches.length <= _recentSearchPreviewLimit) {
        _showAllRecentSearches = false;
      }
      notifyListeners();
    }
  }

  /// Switches between the collapsed and expanded history states.
  void toggleRecentSearchVisibility() {
    if (!shouldShowRecentSearchToggle) {
      return;
    }

    _showAllRecentSearches = !_showAllRecentSearches;
    notifyListeners();
  }

  static List<SearchSuggestion> _buildSuggestions() {
    final suggestions = <SearchSuggestion>[
      const SearchSuggestion(
        name: 'Coconut sa Caybiga',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Strawberry in Baguio',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Rice',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Kamote',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Mangoes',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Eggplant',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Banana',
        imageAssetPath: AppAssets.placeholderImage,
      ),
      const SearchSuggestion(
        name: 'Tomatoes',
        imageAssetPath: AppAssets.placeholderImage,
      ),
    ];

    suggestions.shuffle(Random());
    return suggestions;
  }
}
