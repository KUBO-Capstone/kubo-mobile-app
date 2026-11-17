import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';
import 'order_service.dart';

/// Lifecycle of an offer. Mirrors the `negotiations.status` CHECK constraint.
///
/// The status doubles as a turn marker: [pending] waits on the seller,
/// [countered] waits on the buyer. A counter rewrites the terms on the same
/// negotiation rather than creating a new one. Accepting locks the terms
/// and, for an offer that says how the produce changes hands, creates the
/// order there and then; [declined] also covers an accepted offer that was
/// cancelled before it was ordered.
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

/// Why a seller turned an offer down. Mirrors `DECLINE_REASONS` in the
/// backend; shown to the buyer in the thread so they know what to change.
enum DeclineReason {
  bagsakanTooFar('bagsakan_too_far', 'Selected bagsakan is too far'),
  courierUnavailable('courier_unavailable', 'Courier not available in my area'),
  priceTooLow('price_too_low', 'Price too low');

  const DeclineReason(this.key, this.label);

  /// What the backend stores.
  final String key;
  final String label;

  static DeclineReason? parse(String? raw) {
    for (final reason in values) {
      if (reason.key == raw) return reason;
    }
    return null;
  }
}

/// How the produce changes hands under an offer's terms: picked up at a
/// bagsakan center, or sent by a courier. Agreed with the price, and locked
/// in when the offer is accepted.
class OfferFulfillment {
  const OfferFulfillment.pickup({required int this.centerId, this.centerName})
      : method = DeliveryMethod.meetup,
        courierName = null;

  const OfferFulfillment.courier({required String this.courierName})
      : method = DeliveryMethod.courier,
        centerId = null,
        centerName = null;

  const OfferFulfillment._(this.method, this.centerId, this.centerName, this.courierName);

  /// Reads the terms off an offer row; null for offers from before terms
  /// carried them.
  static OfferFulfillment? fromJson(Map<String, dynamic> json) {
    final raw = json['delivery_method']?.toString();
    if (raw != 'meetup' && raw != 'courier') return null;
    return OfferFulfillment._(
      DeliveryMethod.parse(raw),
      (json['drop_off_center_id'] as num?)?.toInt(),
      json['center_name']?.toString(),
      json['courier_name']?.toString(),
    );
  }

  final DeliveryMethod method;
  final int? centerId;
  final String? centerName;
  final String? courierName;

  bool get isPickup => method == DeliveryMethod.meetup;

  /// "Pickup at Malolos Kubo Bagsakan Center" / "Lalamove delivery".
  String get label => isPickup
      ? 'Pickup at ${centerName ?? 'a bagsakan center'}'
      : '${courierName ?? 'Courier'} delivery';

  Map<String, Object?> toJson() => {
        'delivery_method': method.name,
        if (isPickup) 'drop_off_center_id': centerId,
        if (!isPickup) 'courier_name': courierName,
      };

  @override
  bool operator ==(Object other) =>
      other is OfferFulfillment && other.method == method && other.centerId == centerId && other.courierName == courierName;

  @override
  int get hashCode => Object.hash(method, centerId, courierName);
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
    required this.allowsMeetup,
    required this.allowsDelivery,
    this.fulfillment,
    this.declineReason,
    this.orderId,
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
      allowsMeetup: json['allows_meetup'] != false,
      allowsDelivery: json['allows_delivery'] != false,
      fulfillment: OfferFulfillment.fromJson(json),
      declineReason: DeclineReason.parse(json['decline_reason']?.toString()),
      orderId: (json['order_id'] as num?)?.toInt(),
    );
  }

  /// Deal methods the seller accepts on this listing; the offer and order
  /// forms only offer these.
  final bool allowsMeetup;
  final bool allowsDelivery;

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

  /// How the produce changes hands under these terms; null on offers from
  /// before terms carried it, which are ordered the old way.
  final OfferFulfillment? fulfillment;

  /// Why the seller declined, when they said.
  final DeclineReason? declineReason;

  /// The order an accept created; only set on the answer to that accept.
  final int? orderId;

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

/// Actions accepted by `PATCH /api/negotiations/:id`. [cancel] calls off an
/// accepted offer that has not been ordered yet, which puts the quantity it
/// was holding back on the listing.
enum NegotiationAction { accept, decline, counter, cancel }

/// HTTP client for the negotiation endpoints. The acting user is whoever the
/// token says is signed in.
class NegotiationService {
  NegotiationService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  /// Negotiations the signed-in user is a party to. `role` narrows to `buyer`
  /// (sent) or `seller` (received).
  Future<List<NegotiationRecord>> fetchNegotiations({
    String? role,
    NegotiationStatus? status,
  }) async {
    final uri = Uri.parse('$_baseUrl/negotiations').replace(queryParameters: {
      if (role != null) 'role': role,
      if (status != null) 'status': status.name,
    });
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(NegotiationRecord.fromJson)
        .toList(growable: false);
  }

  /// Opens an offer: a price, a quantity, and how the buyer wants the
  /// produce handed over.
  Future<NegotiationRecord> createOffer({
    required int productId,
    required double price,
    required double quantity,
    required OfferFulfillment fulfillment,
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/negotiations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'product_id': productId,
          'offered_price': price,
          'offered_quantity': quantity,
          ...fulfillment.toJson(),
        }),
      ),
    );
    return NegotiationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Accept, decline, counter or cancel. `price`, `quantity` and
  /// `fulfillment` are only read for a counter; `reason` only for a seller's
  /// decline.
  Future<NegotiationRecord> respond({
    required int negotiationId,
    required NegotiationAction action,
    double? price,
    double? quantity,
    OfferFulfillment? fulfillment,
    DeclineReason? reason,
  }) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('$_baseUrl/negotiations/$negotiationId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action.name,
          if (price != null) 'offered_price': price,
          if (quantity != null) 'offered_quantity': quantity,
          ...?fulfillment?.toJson(),
          if (reason != null) 'reason': reason.key,
        }),
      ),
    );
    return NegotiationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Tells the server the signed-in user has seen the "deal closed" screen
  /// (shown once the buyer has confirmed receipt), so it is not shown again
  /// on any device.
  Future<void> markCelebrated({required int negotiationId}) async {
    final response = await sendRequest(
      () => _client.post(Uri.parse('$_baseUrl/negotiations/$negotiationId/celebrated')),
    );
    checkResponse(response);
  }

  void dispose() => _client.close();
}
