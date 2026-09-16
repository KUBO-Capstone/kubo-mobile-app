import 'package:flutter/foundation.dart';

import '../../../shared/data/market_service.dart';

/// Dashboard (table) or map presentation of one product's area prices.
enum MarketDetailView { dashboard, map }

/// State for one product's price-per-area screen.
class MarketProductController extends ChangeNotifier {
  MarketProductController({required this.productId, MarketService? service})
      : _service = service ?? MarketService();

  final int productId;
  final MarketService _service;

  /// Long label of the region the map opens on when it has data.
  static const _defaultRegionName = 'National Capital Region';

  MarketProductDetail? product;
  bool isLoading = true;
  String? errorMessage;

  MarketDetailView view = MarketDetailView.dashboard;

  /// Region the map is narrowed to (its long name); null shows every region.
  String? selectedRegionName;

  /// Area whose card is open under the map.
  MarketAreaPrice? selectedArea;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final detail = await _service.fetchProduct(productId);
      product = detail;
      // Default the map to one region so it opens zoomed in on something
      // rather than the whole archipelago - NCR when it has data (it is the
      // region with placed market pins), otherwise the first alphabetically.
      selectedRegionName ??= detail.regionNames.contains(_defaultRegionName)
          ? _defaultRegionName
          : detail.regionNames.firstOrNull;
      selectedArea = _visibleAreasFor(detail).firstOrNull;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void showView(MarketDetailView next) {
    if (view == next) return;
    view = next;
    notifyListeners();
  }

  void selectRegion(String? regionName) {
    selectedRegionName = regionName;
    final detail = product;
    selectedArea = detail == null ? null : _visibleAreasFor(detail).firstOrNull;
    notifyListeners();
  }

  void selectArea(MarketAreaPrice area) {
    selectedArea = area;
    notifyListeners();
  }

  // "All regions" plots one pin per region at its centroid (the regional
  // average); a selected region plots its markets. Markets DA names but we
  // have no coordinates for (see backend market/market-areas.ts) cannot be
  // pinned, so a region with none placed falls back to its own centroid pin.
  List<MarketAreaPrice> _visibleAreasFor(MarketProductDetail detail) {
    final region = selectedRegionName;
    if (region == null) return detail.areas.where((a) => a.hasCoordinates).toList(growable: false);
    final markets = detail.markets.where((m) => m.regionName == region && m.hasCoordinates).toList(growable: false);
    if (markets.isNotEmpty) return markets;
    return detail.areas.where((a) => a.regionName == region && a.hasCoordinates).toList(growable: false);
  }

  /// Pins on the map: the selected region's markets, or one pin per region.
  List<MarketAreaPrice> get visibleAreas {
    final detail = product;
    return detail == null ? const [] : _visibleAreasFor(detail);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
