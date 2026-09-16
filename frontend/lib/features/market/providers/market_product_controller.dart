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
      // Default the map to the first region so it opens zoomed in on
      // something rather than the whole archipelago.
      selectedRegionName ??= detail.regionNames.firstOrNull;
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

  List<MarketAreaPrice> _visibleAreasFor(MarketProductDetail detail) {
    final region = selectedRegionName;
    if (region == null) return detail.areas;
    return detail.areas.where((a) => a.regionName == region).toList(growable: false);
  }

  /// Areas plotted on the map: the selected region's, or all of them.
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
