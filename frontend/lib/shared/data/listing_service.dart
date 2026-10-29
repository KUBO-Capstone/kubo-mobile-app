import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_config.dart';
import 'api_request.dart';
import 'listing_options.dart';
import 'synthetic_records.dart';

/// Everything the create / edit form sends for one listing.
class ListingSubmission {
  const ListingSubmission({
    required this.cropName,
    required this.category,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.description,
    required this.qualityGrade,
    required this.farmingMethod,
    required this.harvestDate,
    required this.isPreorder,
    required this.allowsMeetup,
    required this.allowsDelivery,
    required this.images,
  });

  final String cropName;
  final String category;
  final double price;
  final double quantity;
  final String unit;
  final String description;
  final String qualityGrade;
  final String farmingMethod;
  final DateTime? harvestDate;
  final bool isPreorder;
  final bool allowsMeetup;
  final bool allowsDelivery;

  /// Server paths or URLs from [ListingService.uploadImages], cover first.
  final List<String> images;

  Map<String, dynamic> toJson() => {
        'crop_name': cropName,
        'category': category,
        'base_price': price,
        'available_quantity': quantity,
        'unit_measurement': unit,
        'description': description,
        'quality_grade': qualityGrade,
        'farming_method': farmingMethod,
        'harvest_date': harvestDate == null ? null : toApiDate(harvestDate!),
        'is_preorder': isPreorder,
        'allows_meetup': allowsMeetup,
        'allows_delivery': allowsDelivery,
        'images': images,
      };
}

class ListingService {
  ListingService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  /// [includeUnavailable] also returns the seller's sold-out listings; only
  /// the owner's profile tab asks for them.
  Future<List<SyntheticListingRecord>> fetchListings({
    String query = '',
    int? sellerId,
    bool includeUnavailable = false,
  }) async {
    final queryParameters = <String, String>{};
    if (query.trim().isNotEmpty) queryParameters['q'] = query.trim();
    if (sellerId != null) queryParameters['seller_id'] = '$sellerId';
    if (includeUnavailable) queryParameters['include_unavailable'] = 'true';
    final uri = Uri.parse('$_baseUrl/products').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(SyntheticListingRecord.fromJson)
        .toList(growable: false);
  }

  /// One listing by id, whatever its status (the chat header links to it
  /// even after it is sold out).
  Future<SyntheticListingRecord> fetchListing(int productId) async {
    final response = await sendRequest(() => _client.get(Uri.parse('$_baseUrl/products/$productId')));
    return SyntheticListingRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Stores photos for a listing about to be saved and returns their
  /// server paths, in the same order, for [ListingSubmission.images].
  Future<List<String>> uploadImages(List<File> files) async {
    if (files.isEmpty) return const <String>[];
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/products/images'));
    for (final file in files) {
      final extension = file.path.split('.').last.toLowerCase();
      final subtype = switch (extension) {
        'png' => 'png',
        'webp' => 'webp',
        _ => 'jpeg',
      };
      request.files.add(
        await http.MultipartFile.fromPath('images', file.path, contentType: MediaType('image', subtype)),
      );
    }
    // Photos take longer than the usual JSON round trip on rural data.
    final response = await sendRequest(
      () async => http.Response.fromStream(await _client.send(request)),
      timeout: const Duration(seconds: 90),
    );
    final data = readData(response) as Map<String, dynamic>;
    return (data['images'] as List<dynamic>).whereType<String>().toList(growable: false);
  }

  /// Lists produce as the signed-in user.
  Future<SyntheticListingRecord> createListing(ListingSubmission listing) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(listing.toJson()),
      ),
    );
    return SyntheticListingRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Seller edits the whole listing, photos included.
  Future<SyntheticListingRecord> updateListing({
    required int productId,
    required ListingSubmission listing,
  }) {
    return _patch(productId, listing.toJson());
  }

  /// Marks the listing sold out ([soldOut] true) or available again.
  Future<SyntheticListingRecord> setSoldOut({
    required int productId,
    required bool soldOut,
  }) {
    return _patch(productId, {
      'status': soldOut ? 'out of stock' : 'available',
    });
  }

  /// Removes the listing from every view. The backend delists rather than
  /// deletes so buyers' past offers on it still resolve.
  Future<void> removeListing({required int productId}) async {
    final response = await sendRequest(
      () => _client.delete(Uri.parse('$_baseUrl/products/$productId')),
    );
    checkResponse(response);
  }

  Future<SyntheticListingRecord> _patch(int productId, Map<String, dynamic> body) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('$_baseUrl/products/$productId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return SyntheticListingRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}