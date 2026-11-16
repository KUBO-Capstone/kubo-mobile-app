import 'package:flutter/foundation.dart';

import '../../../shared/data/listing_service.dart';
import '../../../shared/data/market_service.dart';
import '../../../shared/data/synthetic_records.dart';

class ListingPageController extends ChangeNotifier {
  ListingPageController({
    required SyntheticListingRecord listing,
    ListingService? listings,
  })  : _listing = listing,
        _listings = listings ?? ListingService();

  SyntheticListingRecord _listing;

  /// Set once the seller edits, archives or removes the listing from this
  /// page, so the caller knows to refresh its list when we pop.
  bool _changed = false;

  int _currentImageIndex = 0;
  bool _disposed = false;

  final MarketService _market = MarketService();
  final ListingService _listings;

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

  /// Fetches the listing again. The page opens on the copy its card already
  /// had, which can be behind: accepting an offer takes its quantity off the
  /// listing, and a listing with nothing left reads sold out. Called when
  /// the page opens, when it comes back from a chat, and whenever a deal on
  /// any listing moves. A failure keeps what is on screen.
  Future<void> refresh() async {
    final productId = _listing.productId;
    if (productId == null) return;
    try {
      final latest = await _listings.fetchListing(productId);
      if (_disposed) return;
      _listing = latest;
      notifyListeners();
    } catch (error) {
      debugPrint('Listing refresh failed: $error');
    }
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

  /// The listing's photos, cover first; mock rows fall back to their asset.
  List<String> get images =>
      _listing.images.isEmpty ? <String>[_listing.imageAssetPath] : _listing.images;

  int get currentImageIndex => _currentImageIndex;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _market.dispose();
    _listings.dispose();
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
