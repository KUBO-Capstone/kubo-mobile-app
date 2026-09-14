import 'package:flutter/foundation.dart';

import '../../../shared/data/synthetic_records.dart';

class ListingPageController extends ChangeNotifier {
  ListingPageController({
    required SyntheticListingRecord listing,
    List<String>? images,
  })  : _listing = listing,
        _images = images ?? const <String>[],
        _isFavorite = false;

  SyntheticListingRecord _listing;
  final List<String> _images;

  /// Set once the seller edits, archives or removes the listing from this
  /// page, so the caller knows to refresh its list when we pop.
  bool _changed = false;

  bool _isFavorite = false;
  int _currentImageIndex = 0;

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

  bool get isFavorite => _isFavorite;

  int get currentImageIndex => _currentImageIndex;

  void toggleFavorite() {
    _isFavorite = !_isFavorite;
    notifyListeners();
  }

  void updateCurrentImage(int index) {
    if (index == _currentImageIndex) {
      return;
    }

    _currentImageIndex = index;
    notifyListeners();
  }
}
