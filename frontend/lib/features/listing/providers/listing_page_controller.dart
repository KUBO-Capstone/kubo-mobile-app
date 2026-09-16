import 'package:flutter/foundation.dart';

import '../../../shared/data/market_service.dart';
import '../../../shared/data/synthetic_records.dart';

class ListingPageController extends ChangeNotifier {
  ListingPageController({
    required SyntheticListingRecord listing,
    List<String>? images,
  })  : _listing = listing,
        _images = images ?? const <String>[];

  SyntheticListingRecord _listing;
  final List<String> _images;

  /// Set once the seller edits, archives or removes the listing from this
  /// page, so the caller knows to refresh its list when we pop.
  bool _changed = false;

  int _currentImageIndex = 0;

  final MarketService _market = MarketService();

  /// Market Watch reference for this crop in the seller's region; null when
  /// nothing matched (mock rows, unknown crops, server down).
  MarketReference? marketReference;

  /// Looks up the reference price. Failures are silent: the comparison is a
  /// hint under the price, not something the page depends on.
  Future<void> loadMarketReference() async {
    if (_listing.productId == null) return;
    try {
      marketReference = await _market.fetchReference(
        crop: _listing.title,
        region: _listing.regionLabel,
      );
    } catch (error) {
      debugPrint('Market reference lookup failed: $error');
      marketReference = null;
    }
    notifyListeners();
  }

  SyntheticListingRecord get listing => _listing;

  bool get changed => _changed;

  /// Swaps in the record returned by the server after a seller action.
  void replaceListing(SyntheticListingRecord listing) {
    _listing = listing;
    _changed = true;
    notifyListeners();
  }

  /// Marks the listing as removed; the page pops right after.
  void markRemoved() {
    _changed = true;
  }

  List<String> get images => List<String>.unmodifiable(_images);

  int get currentImageIndex => _currentImageIndex;

  @override
  void dispose() {
    _market.dispose();
    super.dispose();
  }

  void updateCurrentImage(int index) {
    if (index == _currentImageIndex) {
      return;
    }

    _currentImageIndex = index;
    notifyListeners();
  }
}
