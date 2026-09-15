import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';

/// Lifecycle of an offer. Mirrors the `negotiations.status` CHECK constraint.
///
/// The status doubles as a turn marker: [pending] waits on the seller,
/// [countered] waits on the buyer. A counter rewrites the price on the same
/// negotiation rather than creating a new one.
enum NegotiationStatus {
  pending,
  countered,
  accepted,
  declined;

  static NegotiationStatus parse(String? raw) => NegotiationStatus.values.firstWhere(
        (status) => status.name == raw,
        orElse: () => NegotiationStatus.pending,
      );

  bool get isOpen => this == pending || this == countered;
}

/// One buyer/seller price negotiation on a listing, as returned by
/// `GET /api/negotiations`.
class NegotiationRecord {
  const NegotiationRecord({
    required this.id,
    required this.conversationId,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.offeredPrice,
    required this.offeredQuantity,
    required this.status,
    required this.cropName,
    required this.unit,
    required this.basePrice,
    required this.buyerName,
    required this.sellerName,
    required this.createdAt,
  });

  factory NegotiationRecord.fromJson(Map<String, dynamic> json) {
    return NegotiationRecord(
      id: (json['negotiation_id'] as num).toInt(),
      conversationId: (json['conversation_id'] as num).toInt(),
      productId: (json['product_id'] as num).toInt(),
      buyerId: (json['buyer_id'] as num).toInt(),
      sellerId: (json['seller_id'] as num).toInt(),
      offeredPrice: (json['offered_price'] as num).toDouble(),
      offeredQuantity: (json['offered_quantity'] as num).toDouble(),
      status: NegotiationStatus.parse(json['status']?.toString()),
      cropName: json['crop_name']?.toString() ?? 'Listing',
      unit: json['unit_measurement']?.toString() ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      buyerName: json['buyer_name']?.toString() ?? 'Buyer',
      sellerName: json['seller_name']?.toString() ?? 'Seller',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  final int id;

  /// Thread this offer lives in; the chat screen opens on it after an offer.
  final int conversationId;
  final int productId;
  final int buyerId;
  final int sellerId;
  final double offeredPrice;
  final double offeredQuantity;
  final NegotiationStatus status;
  final String cropName;
  final String unit;
  final double basePrice;
  final String buyerName;
  final String sellerName;
  final DateTime? createdAt;

  bool isBuyer(int userId) => buyerId == userId;
  bool isSeller(int userId) => sellerId == userId;

  /// Name of the other party from [userId]'s point of view.
  String counterpartyName(int userId) => isBuyer(userId) ? sellerName : buyerName;

  /// Whether [userId] is the one expected to act next.
  bool isTurnOf(int userId) {
    switch (status) {
      case NegotiationStatus.pending:
        return isSeller(userId);
      case NegotiationStatus.countered:
        return isBuyer(userId);
      case NegotiationStatus.accepted:
      case NegotiationStatus.declined:
        return false;
    }
  }

  double get total => offeredPrice * offeredQuantity;
}

/// Actions accepted by `PATCH /api/negotiations/:id`.
enum NegotiationAction { accept, decline, counter }

/// HTTP client for the negotiation endpoints.
///
/// KNOWN DEBT: the acting user is sent in the body (`buyer_id` / `user_id`)
/// because there is no auth token yet. When PLAN.md Phase 2 lands, drop those
/// fields here and nothing else in the app should have to change.
class NegotiationService {
  NegotiationService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  /// Negotiations [userId] is a party to. `role` narrows to `buyer` (sent) or
  /// `seller` (received).
  Future<List<NegotiationRecord>> fetchNegotiations({
    required int userId,
    String? role,
    NegotiationStatus? status,
  }) async {
    final uri = Uri.parse('$_baseUrl/negotiations').replace(queryParameters: {
      'user_id': '$userId',
      if (role != null) 'role': role,
      if (status != null) 'status': status.name,
    });
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(NegotiationRecord.fromJson)
        .toList(growable: false);
  }

  Future<NegotiationRecord> createOffer({
    required int buyerId,
    required int productId,
    required double price,
    required double quantity,
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/negotiations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'buyer_id': buyerId,
          'product_id': productId,
          'offered_price': price,
          'offered_quantity': quantity,
        }),
      ),
    );
    return NegotiationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Accept, decline, or counter. `price`/`quantity` are only read for a counter.
  Future<NegotiationRecord> respond({
    required int negotiationId,
    required int userId,
    required NegotiationAction action,
    double? price,
    double? quantity,
  }) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('$_baseUrl/negotiations/$negotiationId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'action': action.name,
          if (price != null) 'offered_price': price,
          if (quantity != null) 'offered_quantity': quantity,
        }),
      ),
    );
    return NegotiationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
