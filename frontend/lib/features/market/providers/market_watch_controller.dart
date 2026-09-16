import 'package:flutter/foundation.dart';

import '../../../shared/data/market_service.dart';

/// State for the Market tab: the full product table, narrowed by the search
/// box and the classification chips. Everything is fetched once and filtered
/// locally so typing feels instant; the table is two dozen rows.
class MarketWatchController extends ChangeNotifier {
  MarketWatchController({MarketService? service}) : _service = service ?? MarketService();

  /// Rows shown per classification before "See more" expands it.
  static const collapsedRowLimit = 3;

  final MarketService _service;

  List<MarketProductSummary> _all = const [];
  bool isLoading = false;
  String? errorMessage;

  String query = '';

  /// Null means the "All" chip.
  String? classification;

  /// Classifications the user expanded past [collapsedRowLimit].
  final Set<String> expanded = <String>{};

  /// Products whose current figures come from the DA import (vs. the seed).
  int get realDataCount => _all.where((p) => p.isRealData).length;

  /// Newest DA date across products; null until the importer has run.
  DateTime? get latestRealAsOf {
    DateTime? latest;
    for (final p in _all) {
      final date = p.asOf;
      if (p.isRealData && date != null && (latest == null || date.isAfter(latest))) latest = date;
    }
    return latest;
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _all = await _service.fetchProducts();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    final next = value.trim();
    if (next == query) return;
    query = next;
    notifyListeners();
  }

  void setClassification(String? value) {
    if (value == classification) return;
    classification = value;
    notifyListeners();
  }

  void toggleExpanded(String classificationName) {
    if (!expanded.remove(classificationName)) {
      expanded.add(classificationName);
    }
    notifyListeners();
  }

  bool _matches(MarketProductSummary product) {
    if (classification != null && product.classification != classification) return false;
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return product.name.toLowerCase().contains(needle) ||
        product.groups.any((g) => g.toLowerCase().contains(needle));
  }

  /// Products grouped by classification, in the tab's fixed order, only for
  /// classifications that have at least one match.
  List<MapEntry<String, List<MarketProductSummary>>> get grouped {
    final visible = _all.where(_matches).toList(growable: false);
    return [
      for (final name in marketClassifications)
        if (visible.any((p) => p.classification == name))
          MapEntry(name, visible.where((p) => p.classification == name).toList(growable: false)),
    ];
  }

  bool get hasData => _all.isNotEmpty;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
