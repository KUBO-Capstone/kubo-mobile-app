import 'package:flutter/foundation.dart';

import '../../../shared/data/synthetic_records.dart';

class ListingPageController extends ChangeNotifier {
  ListingPageController({
    required SyntheticListingRecord listing,
    List<String>? images,
  })  : _listing = listing,
        _images = images ?? const <String>[],
        _isFavorite = false;

  final SyntheticListingRecord _listing;
  final List<String> _images;

  bool _isFavorite = false;
  int _currentImageIndex = 0;

  SyntheticListingRecord get listing => _listing;

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
