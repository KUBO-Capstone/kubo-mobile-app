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

  final String id;
  final String title;
  final String price;
  final String locationLabel;
  final String regionLabel;
  final String sellerLabel;
  final String imageAssetPath;
}