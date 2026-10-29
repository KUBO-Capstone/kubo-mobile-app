import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';

/// Lifecycle of an order. Mirrors the `orders.order_status` CHECK constraint.
///
/// [inTransit] means different things per delivery method: a courier parcel
/// is on its way, or meetup produce has been dropped at the bagsakan center
/// and is waiting for the buyer — see [OrderRecord.statusLabel].
enum OrderStatus {
  pending,
  inTransit,
  delivered,
  cancelled;

  static OrderStatus parse(String? raw) {
    switch (raw) {
      case 'in transit':
        return inTransit;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      default:
        return pending;
    }
  }

  bool get isOpen => this == pending || this == inTransit;
}

/// How the buyer gets the produce. Mirrors `orders.delivery_method`.
enum DeliveryMethod {
  meetup,
  courier;

  static DeliveryMethod parse(String? raw) =>
      raw == 'courier' ? courier : meetup;
}

/// Actions accepted by `PATCH /api/orders/:id`.
enum OrderAction { ship, deliver, cancel }

/// One order, as returned by `GET /api/orders`. An order is always exactly
/// one accepted negotiation, so the single line item is flattened onto it.
class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.negotiationId,
    required this.conversationId,
    required this.buyerId,
    required this.sellerId,
    required this.buyerName,
    required this.sellerName,
    required this.productId,
    required this.cropName,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.total,
    required this.status,
    required this.deliveryMethod,
    required this.orderDate,
    required this.updatedAt,
    this.productImage,
    this.centerId,
    this.centerName,
    this.centerLocation,
    this.centerAddress,
    this.courierName,
    this.trackingNumber,
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    return OrderRecord(
      id: (json['order_id'] as num).toInt(),
      negotiationId: (json['negotiation_id'] as num).toInt(),
      conversationId: (json['conversation_id'] as num).toInt(),
      buyerId: (json['buyer_id'] as num).toInt(),
      sellerId: (json['seller_id'] as num).toInt(),
      buyerName: json['buyer_name']?.toString() ?? 'Buyer',
      sellerName: json['seller_name']?.toString() ?? 'Seller',
      productId: (json['product_id'] as num).toInt(),
      cropName: json['crop_name']?.toString() ?? 'Listing',
      unit: json['unit_measurement']?.toString() ?? '',
      productImage: resolveMediaUrl(json['product_image']?.toString()),
      quantity: (json['quantity'] as num).toDouble(),
      price: (json['negotiated_price'] as num).toDouble(),
      total: (json['total_amount'] as num).toDouble(),
      status: OrderStatus.parse(json['order_status']?.toString()),
      deliveryMethod: DeliveryMethod.parse(json['delivery_method']?.toString()),
      centerId: (json['drop_off_center_id'] as num?)?.toInt(),
      centerName: json['center_name']?.toString(),
      centerLocation: json['center_location']?.toString(),
      centerAddress: json['center_address']?.toString(),
      courierName: json['courier_name']?.toString(),
      trackingNumber: json['tracking_number']?.toString(),
      orderDate: DateTime.tryParse(json['order_date']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  final int id;
  final int negotiationId;

  /// The buyer/seller thread the order was placed from.
  final int conversationId;
  final int buyerId;
  final int sellerId;
  final String buyerName;
  final String sellerName;
  final int productId;
  final String cropName;
  final String unit;
  final String? productImage;
  final double quantity;

  /// Agreed price per [unit].
  final double price;
  final double total;
  final OrderStatus status;
  final DeliveryMethod deliveryMethod;

  /// Bagsakan center for a meetup order; null for courier.
  final int? centerId;
  final String? centerName;
  final String? centerLocation;
  final String? centerAddress;

  /// Set once the seller hands a courier order over.
  final String? courierName;
  final String? trackingNumber;
  final DateTime? orderDate;
  final DateTime? updatedAt;

  bool isBuyer(int userId) => buyerId == userId;
  bool isSeller(int userId) => sellerId == userId;

  String counterpartyName(int userId) => isBuyer(userId) ? sellerName : buyerName;

  bool get isMeetup => deliveryMethod == DeliveryMethod.meetup;

  /// Status in words that fit the delivery method.
  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return isMeetup ? 'Waiting for drop-off' : 'Waiting for dispatch';
      case OrderStatus.inTransit:
        return isMeetup ? 'Ready for pickup' : 'In transit';
      case OrderStatus.delivered:
        return isMeetup ? 'Picked up' : 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// "Pickup at Malolos Kubo Bagsakan Center" / "Courier delivery".
  String get handoverLabel =>
      isMeetup ? 'Pickup at ${centerName ?? 'a bagsakan center'}' : 'Courier delivery';

  /// The seller's next move: drop it at the center or hand it to a courier.
  bool canShip(int userId) => isSeller(userId) && status == OrderStatus.pending;

  /// The buyer's next move: confirm it was picked up / received.
  bool canDeliver(int userId) => isBuyer(userId) && status == OrderStatus.inTransit;

  /// Either side may back out while nothing has moved yet.
  bool canCancel(int userId) =>
      (isBuyer(userId) || isSeller(userId)) && status == OrderStatus.pending;
}

/// HTTP client for the order endpoints. The acting user is whoever the token
/// says is signed in.
class OrderService {
  OrderService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Map<String, String> get _json => const {'Content-Type': 'application/json'};

  /// Orders the signed-in user is a party to. `role` narrows to `buyer`
  /// (purchases) or `seller` (sales).
  Future<List<OrderRecord>> fetchOrders({String? role}) async {
    final uri = Uri.parse('$_baseUrl/orders').replace(queryParameters: {
      if (role != null) 'role': role,
    });
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(OrderRecord.fromJson)
        .toList(growable: false);
  }

  Future<OrderRecord> fetchOrder({required int orderId}) async {
    final uri = Uri.parse('$_baseUrl/orders/$orderId');
    final response = await sendRequest(() => _client.get(uri));
    return OrderRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Turns an accepted negotiation into an order. `centerId` is required for
  /// [DeliveryMethod.meetup] and ignored for courier.
  Future<OrderRecord> placeOrder({
    required int negotiationId,
    required DeliveryMethod method,
    int? centerId,
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/orders'),
        headers: _json,
        body: jsonEncode({
          'negotiation_id': negotiationId,
          'delivery_method': method.name,
          if (centerId != null) 'drop_off_center_id': centerId,
        }),
      ),
    );
    return OrderRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Ship, deliver, or cancel. Courier details are only read for a ship on
  /// a courier order.
  Future<OrderRecord> respond({
    required int orderId,
    required OrderAction action,
    String? courierName,
    String? trackingNumber,
  }) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: _json,
        body: jsonEncode({
          'action': action.name,
          if (courierName != null) 'courier_name': courierName,
          if (trackingNumber != null) 'tracking_number': trackingNumber,
        }),
      ),
    );
    return OrderRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
