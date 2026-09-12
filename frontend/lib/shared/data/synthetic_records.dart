/// Shared synthetic search suggestion used by the mock search experience.
class SyntheticSearchSuggestion {
  const SyntheticSearchSuggestion({
    required this.name,
    required this.imageAssetPath,
  });

  /// Label shown under the suggestion image.
  final String name;

  /// Image asset rendered in the suggestion card.
  final String imageAssetPath;
}

/// Synthetic notification shown while the notification API is unavailable.
class SyntheticNotificationRecord {
  const SyntheticNotificationRecord({
    required this.title,
    required this.message,
    required this.date,
    required this.time,
    required this.imageAssetPath,
  });

  final String title;
  final String message;
  final String date;
  final String time;
  final String imageAssetPath;
}

/// Notifications used by the notification screen during development.
final List<SyntheticNotificationRecord>
syntheticNotifications = <SyntheticNotificationRecord>[
  const SyntheticNotificationRecord(
    title: 'Delivered',
    message: 'Rate your delivered items or your seller.',
    date: 'Yesterday',
    time: '14:18',
    imageAssetPath: 'assets/images/Placeholder_img.png',
  ),
  const SyntheticNotificationRecord(
    title: 'Delivered',
    message:
        'Satisfied with your order? Rate your seller and comment your thoughts.',
    date: '05/31/2026',
    time: '15:16',
    imageAssetPath: 'assets/images/Placeholder_img.png',
  ),
  const SyntheticNotificationRecord(
    title: 'New Offer',
    message: 'user has offered: PHP 200',
    date: '04/24/2026',
    time: '04:29',
    imageAssetPath: 'assets/images/Placeholder_img.png',
  ),
];

/// Shared synthetic listing used by explore and search result screens.
class SyntheticListingRecord {
  const SyntheticListingRecord({
    required this.id,
    required this.title,
    required this.price,
    required this.locationLabel,
    required this.regionLabel,
    required this.sellerLabel,
    required this.imageAssetPath,
    this.description = 'No description available.',
    this.date = 'No date available',
    this.numLikes = 0,
    this.groups = const <String>[],
    this.latitude,
    this.longitude,
    this.productId,
    this.sellerId,
    this.basePrice,
    this.availableQuantity,
    this.unit,
  });

  factory SyntheticListingRecord.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    return SyntheticListingRecord(
      id: '${json['product_id']}',
      title: json['crop_name']?.toString() ?? 'Untitled produce',
      price: 'PHP ${json['base_price']}',
      locationLabel: json['location_label']?.toString() ?? 'Philippines',
      regionLabel: json['region_label']?.toString() ?? 'NCR',
      sellerLabel: json['seller_name']?.toString() ?? 'Kubo grower',
      imageAssetPath: images.isEmpty ? 'assets/images/Placeholder_img.png' : images.first,
      description: json['description']?.toString() ?? 'Fresh local produce from a Kubo grower.',
      date: createdAt == null ? 'Recently posted' : 'Posted ${createdAt.month}/${createdAt.day}/${createdAt.year}',
      groups: <String>[json['category']?.toString() ?? 'produce'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      productId: (json['product_id'] as num?)?.toInt(),
      sellerId: (json['seller_id'] as num?)?.toInt(),
      basePrice: (json['base_price'] as num?)?.toDouble(),
      availableQuantity: (json['available_quantity'] as num?)?.toDouble(),
      unit: json['unit_measurement']?.toString(),
    );
  }

  /// Stable identifier for the record.
  final String id;

  /// Primary title rendered on the card.
  final String title;

  /// Display price label shown in the metadata row.
  final String price;

  /// City or area shown beside the price.
  final String locationLabel;

  /// Region label used for explore filtering.
  final String regionLabel;

  /// Seller name rendered below the title.
  final String sellerLabel;

  /// Image asset used for the card thumbnail.
  final String imageAssetPath;

  /// Full description displayed on the listing detail screen.
  final String description;

  /// Date or freshness label relative to the listing post.
  final String date;

  /// Number of users who liked the listing.
  final int numLikes;

  /// List of product categories such as grains, fruits, or vegetables.
  final List<String> groups;

  /// Seller address latitude, null when the seller has no geocoded address.
  final double? latitude;

  /// Seller address longitude, null when the seller has no geocoded address.
  final double? longitude;

  /// Backend product id. Null for mock records, which cannot receive offers.
  final int? productId;

  /// Backend user id of the seller, used to stop a farmer bidding on their own listing.
  final int? sellerId;

  /// Numeric asking price; [price] is the formatted label.
  final double? basePrice;

  /// Stock on hand, in [unit].
  final double? availableQuantity;

  /// Unit of measurement (`kg`, `piece`, …) from the backend enum.
  final String? unit;

  /// Whether this listing can be plotted on the map view.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether this record came from the API and can be negotiated on.
  bool get canReceiveOffers => productId != null && sellerId != null;
}

/// Synthetic suggestions shown in the Search page.
final List<SyntheticSearchSuggestion> syntheticSearchSuggestions =
    <SyntheticSearchSuggestion>[
      const SyntheticSearchSuggestion(
        name: 'Coconut sa Caybiga',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Strawberry in Baguio',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Rice',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Kamote',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Mangoes',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Eggplant',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Banana',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticSearchSuggestion(
        name: 'Tomatoes',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
    ];

/// Explore listings shown on the home/explore page.
final List<SyntheticListingRecord>
syntheticExploreListings = <SyntheticListingRecord>[
  const SyntheticListingRecord(
    id: 'listing-0',
    title: 'Fresh harvested tomatoes bundle',
    price: 'PHP 120',
    locationLabel: 'Caloocan',
    regionLabel: 'NCR',
    sellerLabel: 'Kubo Grower 1',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Freshly picked tomatoes packed for home cooking, salad prep, and quick serving. Ideal for families, local kitchens, and fresh market supply.',
    date: 'Posted 2 days ago',
    numLikes: 128,
    groups: <String>['vegetables', 'fresh produce'],
  ),
  const SyntheticListingRecord(
    id: 'listing-1',
    title: 'Organic eggplant basket',
    price: 'PHP 155',
    locationLabel: 'Bulacan',
    regionLabel: 'Region III',
    sellerLabel: 'Kubo Grower 2',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Organically grown eggplants harvested in small batches for premium quality and vibrant color. Great for stir-fry, grill, and healthy meals.',
    date: 'Posted 5 days ago',
    numLikes: 95,
    groups: <String>['vegetables', 'organic'],
  ),
  const SyntheticListingRecord(
    id: 'listing-2',
    title: 'Sweet mango harvest box',
    price: 'PHP 190',
    locationLabel: 'Pampanga',
    regionLabel: 'Region III',
    sellerLabel: 'Kubo Grower 3',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Sweet and juicy mangoes sourced from local farms, perfect for snacks, desserts, and fruit baskets for gifting.',
    date: 'Posted 1 day ago',
    numLikes: 214,
    groups: <String>['fruits', 'seasonal'],
  ),
  const SyntheticListingRecord(
    id: 'listing-3',
    title: 'Leafy greens weekly pack',
    price: 'PHP 225',
    locationLabel: 'Laguna',
    regionLabel: 'Region IV-A',
    sellerLabel: 'Kubo Grower 4',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'A weekly bundle of leafy greens harvested fresh from farm rows, ready for soups, salads, and nutrient-rich home meals.',
    date: 'Posted 3 days ago',
    numLikes: 148,
    groups: <String>['vegetables', 'healthy'],
  ),
  const SyntheticListingRecord(
    id: 'listing-4',
    title: 'Farm eggs tray set',
    price: 'PHP 260',
    locationLabel: 'Rizal',
    regionLabel: 'NCR',
    sellerLabel: 'Kubo Grower 5',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Free-range farm eggs collected daily for dependable size, clean shells, and fresh taste for breakfast or baking.',
    date: 'Posted 4 days ago',
    numLikes: 176,
    groups: <String>['poultry', 'protein'],
  ),
  const SyntheticListingRecord(
    id: 'listing-5',
    title: 'Red onion kilo pack',
    price: 'PHP 295',
    locationLabel: 'Quezon',
    regionLabel: 'Region IV-A',
    sellerLabel: 'Kubo Grower 6',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Fresh red onions packed in a kilo-sized bundle, excellent for local dishes, sauces, and flavor enhancement.',
    date: 'Posted 6 days ago',
    numLikes: 83,
    groups: <String>['vegetables', 'staples'],
  ),
  const SyntheticListingRecord(
    id: 'listing-6',
    title: 'Coconut vinegar set',
    price: 'PHP 330',
    locationLabel: 'Cavite',
    regionLabel: 'Region IV-A',
    sellerLabel: 'Kubo Grower 7',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Small-batch coconut vinegar made with natural fermentation, ideal for dressings, marinades, and healthy kitchen use.',
    date: 'Posted 8 days ago',
    numLikes: 102,
    groups: <String>['condiments', 'local'],
  ),
  const SyntheticListingRecord(
    id: 'listing-7',
    title: 'Native rice premium sack',
    price: 'PHP 365',
    locationLabel: 'Batangas',
    regionLabel: 'Region IV-A',
    sellerLabel: 'Kubo Grower 8',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Premium native rice from trusted growers, clean and aromatic for daily meals, family gatherings, and pantry stocking.',
    date: 'Posted 10 days ago',
    numLikes: 237,
    groups: <String>['grains', 'staples'],
  ),
  const SyntheticListingRecord(
    id: 'listing-8',
    title: 'Banana blossoms harvest',
    price: 'PHP 400',
    locationLabel: 'Nueva Ecija',
    regionLabel: 'Region III',
    sellerLabel: 'Kubo Grower 9',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Fresh banana blossoms harvested for traditional dishes and healthy home recipes, carefully packed for daily use.',
    date: 'Posted 2 weeks ago',
    numLikes: 67,
    groups: <String>['fruits', 'vegetables'],
  ),
  const SyntheticListingRecord(
    id: 'listing-9',
    title: 'Seasonal vegetable mix',
    price: 'PHP 435',
    locationLabel: 'Bataan',
    regionLabel: 'Region III',
    sellerLabel: 'Kubo Grower 10',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'A curated mix of seasonal vegetables handpicked for balanced meals, family cooking, and quick home prep.',
    date: 'Posted 1 week ago',
    numLikes: 189,
    groups: <String>['vegetables', 'seasonal'],
  ),
];

/// Synthetic listings used as searchable result records.
final List<SyntheticListingRecord>
syntheticSearchResultListings = <SyntheticListingRecord>[
  const SyntheticListingRecord(
    id: 'search-0',
    title: 'Banana bread starter kit',
    price: 'PHP 110',
    locationLabel: 'Cagayan de Oro',
    regionLabel: 'Region X',
    sellerLabel: 'Green Basket Co.',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'A practical starter pack for banana bread baking, including fresh ingredients and a quick recipe guide for home use.',
    date: 'Posted 3 days ago',
    numLikes: 91,
    groups: <String>['fruits', 'bakery'],
  ),
  const SyntheticListingRecord(
    id: 'search-1',
    title: 'Fresh tomatoes harvest pack',
    price: 'PHP 145',
    locationLabel: 'Caloocan',
    regionLabel: 'NCR',
    sellerLabel: 'Urban Harvest',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'This pack contains freshly harvested tomatoes from local growers, ideal for sauces, salads, and family meals.',
    date: 'Posted 1 day ago',
    numLikes: 144,
    groups: <String>['vegetables', 'fresh produce'],
  ),
  const SyntheticListingRecord(
    id: 'search-2',
    title: 'Mango dessert fruit box',
    price: 'PHP 180',
    locationLabel: 'Baguio',
    regionLabel: 'CAR',
    sellerLabel: 'Summit Farms',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Sweet dessert mangoes packed in a ready-to-gift box, suitable for celebrations, snack trays, and fruit desserts.',
    date: 'Posted 4 days ago',
    numLikes: 202,
    groups: <String>['fruits', 'desserts'],
  ),
  const SyntheticListingRecord(
    id: 'search-3',
    title: 'Coconut vinegar premium bottle',
    price: 'PHP 210',
    locationLabel: 'Laguna',
    regionLabel: 'Region IV-A',
    sellerLabel: 'North Grove',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Premium coconut vinegar with a clean taste and natural fermentation, ideal for dressings, marinades, and healthy cooking.',
    date: 'Posted 7 days ago',
    numLikes: 118,
    groups: <String>['condiments', 'local'],
  ),
  const SyntheticListingRecord(
    id: 'search-4',
    title: 'Kamote chips bundle',
    price: 'PHP 95',
    locationLabel: 'Batangas',
    regionLabel: 'Region IV-A',
    sellerLabel: 'Sunfield Market',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Crunchy kamote chips made from locally grown sweet potato, ideal for snacks and healthy bites on the go.',
    date: 'Posted 2 days ago',
    numLikes: 136,
    groups: <String>['fruits', 'snacks'],
  ),
  const SyntheticListingRecord(
    id: 'search-5',
    title: 'Rice family sack',
    price: 'PHP 375',
    locationLabel: 'Pampanga',
    regionLabel: 'Region III',
    sellerLabel: 'Rural Choice',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'A reliable family-sized rice sack for routine meals, pantry storage, and daily household needs at a fair price.',
    date: 'Posted 9 days ago',
    numLikes: 250,
    groups: <String>['grains', 'staples'],
  ),
  const SyntheticListingRecord(
    id: 'search-6',
    title: 'Eggplant basket fresh pick',
    price: 'PHP 135',
    locationLabel: 'Bulacan',
    regionLabel: 'Region III',
    sellerLabel: 'Harvest Lane',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Freshly picked eggplants from local farm rows, perfect for everyday home meals and vegetable dishes.',
    date: 'Posted 5 days ago',
    numLikes: 112,
    groups: <String>['vegetables', 'fresh produce'],
  ),
  const SyntheticListingRecord(
    id: 'search-7',
    title: 'Strawberry box premium',
    price: 'PHP 260',
    locationLabel: 'Baguio',
    regionLabel: 'CAR',
    sellerLabel: 'Highland Produce',
    imageAssetPath: 'assets/images/Placeholder_img.png',
    description:
        'Premium strawberries harvested at peak ripeness, ideal for gifting, desserts, and fresh fruit bowls.',
    date: 'Posted 6 days ago',
    numLikes: 184,
    groups: <String>['fruits', 'premium'],
  ),
];
