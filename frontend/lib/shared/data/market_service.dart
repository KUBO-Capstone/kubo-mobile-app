import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';

/// `market_prices.source` value the DA Bantay Presyo importer writes;
/// anything else (the seed) is illustrative placeholder data.
const String marketSourceDa = 'da-bantay-presyo';

/// Human label for a `market_prices.source` value.
String marketSourceLabel(String? source) =>
    source == marketSourceDa ? 'DA Bantay Presyo' : 'Illustrative seed data';

/// Market Watch classifications, in the order the tab shows them. Mirrors
/// the CHECK constraint on `market_products.classification`.
const List<String> marketClassifications = <String>[
  'Food Products',
  'Fiber Products',
  'Fuel Products',
  'Raw Materials',
];

/// One line of the Market tab table (`GET /api/market/products`).
class MarketProductSummary {
  const MarketProductSummary({
    required this.id,
    required this.name,
    required this.classification,
    required this.groups,
    required this.unit,
    this.dtiSrp,
    this.asOf,
    this.source,
    this.nationwideAvg,
    this.changePct,
  });

  factory MarketProductSummary.fromJson(Map<String, dynamic> json) {
    return MarketProductSummary(
      id: (json['market_product_id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      classification: json['classification']?.toString() ?? '',
      groups: (json['groups'] as List<dynamic>? ?? const []).map((g) => g.toString()).toList(growable: false),
      unit: json['unit_measurement']?.toString() ?? 'kg',
      dtiSrp: (json['dti_srp'] as num?)?.toDouble(),
      asOf: DateTime.tryParse(json['as_of']?.toString() ?? ''),
      source: json['source']?.toString(),
      nationwideAvg: (json['nationwide_avg'] as num?)?.toDouble(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
    );
  }

  final int id;
  final String name;
  final String classification;
  final List<String> groups;
  final String unit;
  final double? dtiSrp;

  /// Newest recorded date across regions.
  final DateTime? asOf;

  /// Where the current figures come from; see [marketSourceLabel].
  final String? source;
  final double? nationwideAvg;

  /// Change of the nationwide average vs. a week earlier, in percent.
  final double? changePct;

  bool get isRealData => source == marketSourceDa;
}

/// One dashboard row (a region's aggregate) or one map pin (a market).
class MarketAreaPrice {
  const MarketAreaPrice({
    required this.region,
    required this.regionName,
    required this.provinceCity,
    required this.avgPrice,
    required this.lowestPrice,
    required this.highestPrice,
    required this.unit,
    this.isRegion = false,
    this.sampleSize = 1,
    this.latitude,
    this.longitude,
    this.asOf,
    this.source,
    this.changePct,
  });

  factory MarketAreaPrice.fromJson(Map<String, dynamic> json) {
    return MarketAreaPrice(
      region: json['region']?.toString() ?? '',
      regionName: json['region_name']?.toString() ?? '',
      isRegion: json['area_type'] == 'region',
      provinceCity: json['province_city']?.toString() ?? '',
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
      lowestPrice: (json['lowest_price'] as num?)?.toDouble() ?? 0,
      highestPrice: (json['highest_price'] as num?)?.toDouble() ?? 0,
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 1,
      unit: json['unit_measurement']?.toString() ?? 'kg',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      asOf: DateTime.tryParse(json['as_of']?.toString() ?? ''),
      source: json['source']?.toString(),
      changePct: (json['change_pct'] as num?)?.toDouble(),
    );
  }

  final String region;
  final String regionName;

  /// True for a region's aggregate row; false for a single market.
  final bool isRegion;

  /// Market name for a market row; empty for a region row.
  final String provinceCity;
  final double avgPrice;
  final double lowestPrice;
  final double highestPrice;

  /// Markets behind a region row; 1 for a market row.
  final int sampleSize;
  final String unit;
  final double? latitude;
  final double? longitude;
  final DateTime? asOf;
  final String? source;
  final double? changePct;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// "National Capital Region" for a region, "National Capital Region -
  /// Commonwealth Market" for one of its markets.
  String get title => isRegion || provinceCity.isEmpty ? regionName : '$regionName - $provinceCity';
}

/// Product dashboard (`GET /api/market/products/:id`).
class MarketProductDetail extends MarketProductSummary {
  const MarketProductDetail({
    required super.id,
    required super.name,
    required super.classification,
    required super.groups,
    required super.unit,
    required this.areas,
    required this.markets,
    super.dtiSrp,
    super.asOf,
    super.source,
    super.nationwideAvg,
    super.changePct,
    this.highestPrice,
    this.lowestPrice,
  });

  factory MarketProductDetail.fromJson(Map<String, dynamic> json) {
    final summary = MarketProductSummary.fromJson(json);
    List<MarketAreaPrice> rows(String key) => (json[key] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MarketAreaPrice.fromJson)
        .toList(growable: false);
    return MarketProductDetail(
      id: summary.id,
      name: summary.name,
      classification: summary.classification,
      groups: summary.groups,
      unit: summary.unit,
      dtiSrp: summary.dtiSrp,
      asOf: summary.asOf,
      source: summary.source,
      nationwideAvg: summary.nationwideAvg,
      changePct: summary.changePct,
      highestPrice: (json['highest_price'] as num?)?.toDouble(),
      lowestPrice: (json['lowest_price'] as num?)?.toDouble(),
      areas: rows('areas'),
      markets: rows('markets'),
    );
  }

  /// Highest / lowest recorded price across every region at its latest date.
  final double? highestPrice;
  final double? lowestPrice;

  /// One aggregate row per region with current data (the dashboard table).
  final List<MarketAreaPrice> areas;

  /// Every market with a price at its region's latest date (the map pins).
  final List<MarketAreaPrice> markets;

  /// Distinct regions with prices, in table order, for the map dropdown.
  List<String> get regionNames =>
      areas.map((a) => a.regionName).toSet().toList(growable: false);
}

/// Reference price shown under a listing's asking price
/// (`GET /api/market/reference?crop=&region=`).
class MarketReference {
  const MarketReference({
    required this.productId,
    required this.name,
    required this.unit,
    this.asOf,
    this.source,
    this.region,
    this.regionAvg,
    this.nationwideAvg,
    this.dtiSrp,
  });

  factory MarketReference.fromJson(Map<String, dynamic> json) {
    return MarketReference(
      productId: (json['market_product_id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      unit: json['unit_measurement']?.toString() ?? 'kg',
      asOf: DateTime.tryParse(json['as_of']?.toString() ?? ''),
      source: json['source']?.toString(),
      region: json['region']?.toString(),
      regionAvg: (json['region_avg'] as num?)?.toDouble(),
      nationwideAvg: (json['nationwide_avg'] as num?)?.toDouble(),
      dtiSrp: (json['dti_srp'] as num?)?.toDouble(),
    );
  }

  final int productId;
  final String name;
  final String unit;
  final DateTime? asOf;

  /// Source of the figure being compared against; see [marketSourceLabel].
  final String? source;

  /// Seller's region, null when no area in that region has a price.
  final String? region;
  final double? regionAvg;
  final double? nationwideAvg;
  final double? dtiSrp;

  /// The number a listing should be compared against: the seller's region
  /// when it has data, otherwise nationwide.
  double? get comparisonPrice => regionAvg ?? nationwideAvg;
}

/// HTTP client for Market Watch. Read-only; nothing here needs a user.
class MarketService {
  MarketService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Future<List<MarketProductSummary>> fetchProducts({String query = '', String? classification}) async {
    final uri = Uri.parse('$_baseUrl/market/products').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (classification != null) 'classification': classification,
    });
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MarketProductSummary.fromJson)
        .toList(growable: false);
  }

  Future<MarketProductDetail> fetchProduct(int productId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('$_baseUrl/market/products/$productId')));
    return MarketProductDetail.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Null when no market product matches the crop (the server answers 404).
  Future<MarketReference?> fetchReference({required String crop, String? region}) async {
    final uri = Uri.parse('$_baseUrl/market/reference').replace(queryParameters: {
      'crop': crop,
      if (region != null && region.trim().isNotEmpty) 'region': region,
    });
    final response = await sendRequest(() => _client.get(uri));
    if (response.statusCode == 404) return null;
    return MarketReference.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
