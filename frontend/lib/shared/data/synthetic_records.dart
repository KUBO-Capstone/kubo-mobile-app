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
  });

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
final List<SyntheticListingRecord> syntheticExploreListings =
    <SyntheticListingRecord>[
      const SyntheticListingRecord(
        id: 'listing-0',
        title: 'Fresh harvested tomatoes bundle',
        price: 'PHP 120',
        locationLabel: 'Caloocan',
        regionLabel: 'NCR',
        sellerLabel: 'Kubo Grower 1',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-1',
        title: 'Organic eggplant basket',
        price: 'PHP 155',
        locationLabel: 'Bulacan',
        regionLabel: 'Region III',
        sellerLabel: 'Kubo Grower 2',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-2',
        title: 'Sweet mango harvest box',
        price: 'PHP 190',
        locationLabel: 'Pampanga',
        regionLabel: 'Region III',
        sellerLabel: 'Kubo Grower 3',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-3',
        title: 'Leafy greens weekly pack',
        price: 'PHP 225',
        locationLabel: 'Laguna',
        regionLabel: 'Region IV-A',
        sellerLabel: 'Kubo Grower 4',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-4',
        title: 'Farm eggs tray set',
        price: 'PHP 260',
        locationLabel: 'Rizal',
        regionLabel: 'NCR',
        sellerLabel: 'Kubo Grower 5',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-5',
        title: 'Red onion kilo pack',
        price: 'PHP 295',
        locationLabel: 'Quezon',
        regionLabel: 'Region IV-A',
        sellerLabel: 'Kubo Grower 6',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-6',
        title: 'Coconut vinegar set',
        price: 'PHP 330',
        locationLabel: 'Cavite',
        regionLabel: 'Region IV-A',
        sellerLabel: 'Kubo Grower 7',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-7',
        title: 'Native rice premium sack',
        price: 'PHP 365',
        locationLabel: 'Batangas',
        regionLabel: 'Region IV-A',
        sellerLabel: 'Kubo Grower 8',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-8',
        title: 'Banana blossoms harvest',
        price: 'PHP 400',
        locationLabel: 'Nueva Ecija',
        regionLabel: 'Region III',
        sellerLabel: 'Kubo Grower 9',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'listing-9',
        title: 'Seasonal vegetable mix',
        price: 'PHP 435',
        locationLabel: 'Bataan',
        regionLabel: 'Region III',
        sellerLabel: 'Kubo Grower 10',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
    ];

/// Synthetic listings used as searchable result records.
final List<SyntheticListingRecord> syntheticSearchResultListings =
    <SyntheticListingRecord>[
      const SyntheticListingRecord(
        id: 'search-0',
        title: 'Banana bread starter kit',
        price: 'PHP 110',
        locationLabel: 'Cagayan de Oro',
        regionLabel: 'Region X',
        sellerLabel: 'Green Basket Co.',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-1',
        title: 'Fresh tomatoes harvest pack',
        price: 'PHP 145',
        locationLabel: 'Caloocan',
        regionLabel: 'NCR',
        sellerLabel: 'Urban Harvest',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-2',
        title: 'Mango dessert fruit box',
        price: 'PHP 180',
        locationLabel: 'Baguio',
        regionLabel: 'CAR',
        sellerLabel: 'Summit Farms',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-3',
        title: 'Coconut vinegar premium bottle',
        price: 'PHP 210',
        locationLabel: 'Laguna',
        regionLabel: 'Region IV-A',
        sellerLabel: 'North Grove',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-4',
        title: 'Kamote chips bundle',
        price: 'PHP 95',
        locationLabel: 'Batangas',
        regionLabel: 'Region IV-A',
        sellerLabel: 'Sunfield Market',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-5',
        title: 'Rice family sack',
        price: 'PHP 375',
        locationLabel: 'Pampanga',
        regionLabel: 'Region III',
        sellerLabel: 'Rural Choice',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-6',
        title: 'Eggplant basket fresh pick',
        price: 'PHP 135',
        locationLabel: 'Bulacan',
        regionLabel: 'Region III',
        sellerLabel: 'Harvest Lane',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
      const SyntheticListingRecord(
        id: 'search-7',
        title: 'Strawberry box premium',
        price: 'PHP 260',
        locationLabel: 'Baguio',
        regionLabel: 'CAR',
        sellerLabel: 'Highland Produce',
        imageAssetPath: 'assets/images/Placeholder_img.png',
      ),
    ];
