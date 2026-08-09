/// Immutable data model that describes one explore listing card.
class ExploreListing {
  const ExploreListing({
    required this.id,
    required this.title,
    required this.price,
    required this.locationLabel,
    required this.regionLabel,
    required this.sellerLabel,
    required this.imageAssetPath,
  });

  /// Stable identifier for the listing used by the UI and future data sync.
  final String id;

  /// Main listing title shown at the top of the card.
  final String title;

  /// Price text shown alongside the listing location.
  final String price;

  /// Friendly location label shown beneath the listing title.
  final String locationLabel;

  /// Region label used by the filter chips and search grouping.
  final String regionLabel;

  /// Seller or grower name shown as supporting metadata.
  final String sellerLabel;

  /// Image asset path displayed in the listing card preview.
  final String imageAssetPath;
}