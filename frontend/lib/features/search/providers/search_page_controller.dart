import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../shared/data/synthetic_records.dart';

/// Holds the transient state for the search page.
class SearchPageController extends ChangeNotifier {
  SearchPageController()
    : suggestions = List<SyntheticSearchSuggestion>.unmodifiable(
        List<SyntheticSearchSuggestion>.from(syntheticSearchSuggestions)
          ..shuffle(Random()),
      );

  static const int _recentSearchPreviewLimit = 4;

  /// Randomized suggestion list rendered under the search history.
  final List<SyntheticSearchSuggestion> suggestions;

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
}
