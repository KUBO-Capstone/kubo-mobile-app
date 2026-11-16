import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/data/listing_service.dart';

/// State for the search page: the searches made this session, the popular
/// produce shown before anything is typed, and the suggestions that follow
/// the text as it is typed.
class SearchPageController extends ChangeNotifier {
  SearchPageController({ListingService? service}) : _service = service ?? ListingService();

  static const int _recentSearchPreviewLimit = 4;

  /// How many of the user's own earlier searches lead the typed suggestions.
  static const int _recentMatchLimit = 3;

  /// Pause after the last keystroke before asking the server, so a word
  /// typed quickly is one request rather than one per letter.
  static const Duration typingPause = Duration(milliseconds: 250);

  final ListingService _service;

  final List<String> _recentSearches = <String>[];

  bool _showAllRecentSearches = false;

  /// The most listed produce right now, for the grid under the history.
  List<ListingSuggestion> popular = const <ListingSuggestion>[];

  /// True until the first fetch of [popular] settles.
  bool isLoadingPopular = true;

  /// Set when [popular] could not be fetched, so the page can offer a retry
  /// instead of claiming there is nothing to suggest.
  bool popularFailed = false;

  /// Suggestions for [typedQuery]. Kept while the next ones load, so the
  /// list does not blink on every keystroke.
  List<ListingSuggestion> matches = const <ListingSuggestion>[];

  /// The text the suggestions are following; empty when nothing is typed.
  String typedQuery = '';

  /// A fetch for [typedQuery] is pending or in flight.
  bool isLoadingMatches = false;

  Timer? _typing;
  bool _disposed = false;

  /// Unmodifiable recent search history.
  List<String> get recentSearches => List<String>.unmodifiable(_recentSearches);

  /// Whether the full recent-search history is currently expanded.
  bool get showAllRecentSearches => _showAllRecentSearches;

  /// Whether the recent-search section should show the See more / See less control.
  bool get shouldShowRecentSearchToggle =>
      _recentSearches.length > _recentSearchPreviewLimit;

  /// Whether the search history contains any entries.
  bool get hasRecentSearches => _recentSearches.isNotEmpty;

  /// Whether the page should show typed suggestions instead of the history
  /// and the popular grid.
  bool get isTyping => typedQuery.isNotEmpty;

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

  /// The user's own earlier searches that contain what is typed, newest
  /// first. They lead the suggestion list, as a search they are likely
  /// repeating.
  List<String> get matchingRecentSearches {
    final needle = typedQuery.toLowerCase();
    if (needle.isEmpty) return const <String>[];
    return _recentSearches
        .where((search) => search.toLowerCase().contains(needle))
        .take(_recentMatchLimit)
        .toList(growable: false);
  }

  /// [matches] without the ones already shown as a recent search.
  List<ListingSuggestion> get freshMatches {
    final shown = matchingRecentSearches.map((search) => search.toLowerCase()).toSet();
    return matches
        .where((suggestion) => !shown.contains(suggestion.text.toLowerCase()))
        .toList(growable: false);
  }

  /// Label shown on the history toggle button.
  String get recentSearchToggleLabel =>
      _showAllRecentSearches ? 'See less' : 'See more';

  /// Fetches the popular produce. A failed refresh keeps what was shown.
  Future<void> loadPopular() async {
    try {
      final suggestions = await _service.fetchSuggestions();
      popular = suggestions;
      popularFailed = false;
    } catch (error) {
      debugPrint('Popular searches fetch failed: $error');
      popularFailed = popular.isEmpty;
    }
    isLoadingPopular = false;
    notifyListeners();
  }

  /// Follows the search field. Suggestions for the new text are fetched once
  /// typing pauses; clearing the field goes back to the history at once.
  void updateTypedQuery(String text) {
    final query = text.trim();
    if (query == typedQuery) return;
    typedQuery = query;
    _typing?.cancel();
    if (query.isEmpty) {
      matches = const <ListingSuggestion>[];
      isLoadingMatches = false;
      notifyListeners();
      return;
    }
    isLoadingMatches = true;
    notifyListeners();
    _typing = Timer(typingPause, () => _loadMatches(query));
  }

  Future<void> _loadMatches(String query) async {
    List<ListingSuggestion>? found;
    try {
      found = await _service.fetchSuggestions(query: query);
    } catch (error) {
      // The "Search for ..." row still works; suggestions are only a help.
      debugPrint('Search suggestions fetch failed: $error');
    }
    // The text moved on while this was in flight; a newer fetch owns the list.
    if (_disposed || query != typedQuery) return;
    matches = found ?? const <ListingSuggestion>[];
    isLoadingMatches = false;
    notifyListeners();
  }

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

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _typing?.cancel();
    _service.dispose();
    super.dispose();
  }
}
