import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';
import 'negotiation_service.dart';
import 'order_service.dart';

/// Kind of chat line. Mirrors the `messages.message_type` CHECK constraint.
///
/// [text] is a typed message; the rest are events the server writes so the
/// thread is also the deal's history: offer events when an offer is made,
/// countered, accepted or declined, [cancelled] when an accepted offer is
/// called off before it is ordered, and [order] when the order behind an
/// accepted offer is placed, shipped, picked up or cancelled.
enum MessageType {
  text,
  offer,
  counter,
  accepted,
  declined,
  cancelled,
  order;

  static MessageType parse(String? raw) => MessageType.values.firstWhere(
        (type) => type.name == raw,
        orElse: () => MessageType.text,
      );

  bool get isOfferEvent => this != text && this != order;
}

/// One line in a conversation, as returned by
/// `GET /api/conversations/:id/messages`.
class MessageRecord {
  const MessageRecord({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.sentAt,
    this.negotiationId,
    this.orderId,
    this.offerPrice,
    this.offerQuantity,
    this.offerDetails,
    this.declineReason,
  });

  factory MessageRecord.fromJson(Map<String, dynamic> json) {
    return MessageRecord(
      id: json['message_id'].toString(),
      conversationId: (json['conversation_id'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      senderName: json['sender_name']?.toString() ?? 'User',
      content: json['content']?.toString() ?? '',
      type: MessageType.parse(json['message_type']?.toString()),
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? ''),
      negotiationId: (json['negotiation_id'] as num?)?.toInt(),
      orderId: (json['order_id'] as num?)?.toInt(),
      offerPrice: (json['offer_price'] as num?)?.toDouble(),
      offerQuantity: (json['offer_quantity'] as num?)?.toDouble(),
      offerDetails: json['offer_details']?.toString(),
      declineReason: DeclineReason.parse(json['decline_reason']?.toString()),
    );
  }

  /// ULID: sorts as a string in send order, so it doubles as the
  /// `?after=` catch-up cursor.
  final String id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime? sentAt;
  final int? negotiationId;

  /// Set on [MessageType.order] lines; opens the order page.
  final int? orderId;
  final double? offerPrice;
  final double? offerQuantity;

  /// How the produce changes hands under the terms this event carries,
  /// e.g. "Pickup at Malolos Kubo Bagsakan Center".
  final String? offerDetails;

  /// On a declined offer: why the seller turned it down, when they said.
  final DeclineReason? declineReason;

  bool isMine(int userId) => senderId == userId;
}

/// One inbox row: the thread plus the listing and the latest offer on it, as
/// returned by `GET /api/conversations`.
class ConversationRecord {
  const ConversationRecord({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.buyerName,
    required this.sellerName,
    required this.productId,
    required this.cropName,
    required this.basePrice,
    required this.unit,
    required this.productStatus,
    required this.allowsMeetup,
    required this.allowsDelivery,
    required this.sellerLocation,
    required this.isUnread,
    this.productImage,
    this.lastMessage,
    this.lastMessageAt,
    this.negotiationId,
    this.negotiationStatus,
    this.offeredPrice,
    this.offeredQuantity,
    this.fulfillment,
    this.declineReason,
    this.orderId,
    this.orderStatus,
    this.acceptedBy,
    this.celebrationPending = false,
    this.myReviewRating,
    this.buyerRating,
    this.buyerReviewCount = 0,
    this.sellerRating,
    this.sellerReviewCount = 0,
  });

  factory ConversationRecord.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['negotiation_status']?.toString();
    final rawOrderStatus = json['order_status']?.toString();
    return ConversationRecord(
      id: (json['conversation_id'] as num).toInt(),
      buyerId: (json['buyer_id'] as num).toInt(),
      sellerId: (json['seller_id'] as num).toInt(),
      buyerName: json['buyer_name']?.toString() ?? 'Buyer',
      sellerName: json['seller_name']?.toString() ?? 'Seller',
      productId: (json['product_id'] as num).toInt(),
      cropName: json['crop_name']?.toString() ?? 'Listing',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      unit: json['unit_measurement']?.toString() ?? '',
      productStatus: json['product_status']?.toString() ?? 'available',
      allowsMeetup: json['allows_meetup'] != false,
      allowsDelivery: json['allows_delivery'] != false,
      productImage: resolveMediaUrl(json['product_image']?.toString()),
      sellerLocation: json['seller_location']?.toString() ?? 'Philippines',
      isUnread: json['is_unread'] == true,
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
      negotiationId: (json['negotiation_id'] as num?)?.toInt(),
      negotiationStatus: rawStatus == null ? null : NegotiationStatus.parse(rawStatus),
      offeredPrice: (json['offered_price'] as num?)?.toDouble(),
      offeredQuantity: (json['offered_quantity'] as num?)?.toDouble(),
      fulfillment: OfferFulfillment.fromJson(json),
      declineReason: DeclineReason.parse(json['decline_reason']?.toString()),
      orderId: (json['order_id'] as num?)?.toInt(),
      orderStatus: rawOrderStatus == null ? null : OrderStatus.parse(rawOrderStatus),
      acceptedBy: (json['accepted_by'] as num?)?.toInt(),
      celebrationPending: json['celebration_pending'] == true,
      myReviewRating: (json['my_review_rating'] as num?)?.toInt(),
      buyerRating: (json['buyer_rating'] as num?)?.toDouble(),
      buyerReviewCount: (json['buyer_review_count'] as num?)?.toInt() ?? 0,
      sellerRating: (json['seller_rating'] as num?)?.toDouble(),
      sellerReviewCount: (json['seller_review_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Who accepted the latest offer: the seller on an offer, the buyer on a
  /// counter. Null until it is accepted.
  final int? acceptedBy;

  /// The buyer has confirmed receipt of the order, and the signed-in user
  /// has not seen the "deal closed" screen for it yet.
  final bool celebrationPending;

  /// How the latest offer says the produce changes hands; null on offers
  /// from before terms carried it.
  final OfferFulfillment? fulfillment;

  /// Why the seller declined the latest offer, when they said.
  final DeclineReason? declineReason;

  /// The signed-in user's rating of the order, null until they review it.
  final int? myReviewRating;
  final double? buyerRating;
  final int buyerReviewCount;
  final double? sellerRating;
  final int sellerReviewCount;

  /// The other party's average rating, from [userId]'s side.
  double? counterpartyRating(int userId) => isBuyer(userId) ? sellerRating : buyerRating;
  int counterpartyReviewCount(int userId) => isBuyer(userId) ? sellerReviewCount : buyerReviewCount;

  /// The order is delivered and [userId] has not rated the other side yet.
  bool canReviewOrder(int userId) =>
      orderId != null && orderStatus == OrderStatus.delivered && myReviewRating == null &&
      (isBuyer(userId) || isSeller(userId));

  final int id;
  final int buyerId;
  final int sellerId;
  final String buyerName;
  final String sellerName;
  final int productId;
  final String cropName;
  final double basePrice;
  final String unit;
  final String productStatus;

  /// Deal methods the seller accepts; passed on to the order page.
  final bool allowsMeetup;
  final bool allowsDelivery;
  final String? productImage;
  final String sellerLocation;
  /// The other party sent something after this user last opened the thread.
  final bool isUnread;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// Latest offer on this thread, open or closed. Null before any offer.
  final int? negotiationId;
  final NegotiationStatus? negotiationStatus;
  final double? offeredPrice;
  final double? offeredQuantity;

  /// The order placed on that latest offer, if any.
  final int? orderId;
  final OrderStatus? orderStatus;

  bool isBuyer(int userId) => buyerId == userId;
  bool isSeller(int userId) => sellerId == userId;

  /// The other party's name from [userId]'s side.
  String counterpartyName(int userId) => isBuyer(userId) ? sellerName : buyerName;

  bool get hasOpenOffer => negotiationStatus?.isOpen ?? false;

  bool get isProductAvailable => productStatus == 'available';

  /// Whether [userId] must act on the current offer (accept / counter / decline).
  bool isOfferTurnOf(int userId) {
    switch (negotiationStatus) {
      case NegotiationStatus.pending:
        return isSeller(userId);
      case NegotiationStatus.countered:
        return isBuyer(userId);
      default:
        return false;
    }
  }

  /// Whether [userId] can open a fresh offer: only the buyer, only when the
  /// last one is closed (or there is none) and the listing is still up. An
  /// accepted offer that has not been ordered yet blocks a new one — the
  /// buyer should place the order (or the seller should wait) instead.
  bool canMakeOffer(int userId) =>
      isBuyer(userId) && !hasOpenOffer && !canPlaceOrder(userId) && isProductAvailable;

  /// Accepted and not yet ordered: only an offer from before terms carried
  /// the handover, whose buyer still has to arrange pickup or delivery. The
  /// listing is holding the agreed quantity for this deal, and either side
  /// can still call it off. An offer with its handover agreed is ordered the
  /// moment it is accepted.
  bool get isAwaitingOrder =>
      negotiationStatus == NegotiationStatus.accepted && orderId == null;

  /// The latest offer was accepted and then cancelled before it was
  /// ordered (a declined offer was never accepted by anyone).
  bool get isDealCancelled =>
      negotiationStatus == NegotiationStatus.declined && acceptedBy != null;

  bool canPlaceOrder(int userId) => isBuyer(userId) && isAwaitingOrder;

  /// Bridges to the negotiation client, which wants a [NegotiationRecord].
  NegotiationRecord? get negotiation {
    final id = negotiationId;
    final status = negotiationStatus;
    if (id == null || status == null) return null;
    return NegotiationRecord(
      id: id,
      conversationId: this.id,
      productId: productId,
      buyerId: buyerId,
      sellerId: sellerId,
      offeredPrice: offeredPrice ?? 0,
      offeredQuantity: offeredQuantity ?? 0,
      status: status,
      cropName: cropName,
      unit: unit,
      basePrice: basePrice,
      buyerName: buyerName,
      sellerName: sellerName,
      createdAt: null,
      allowsMeetup: allowsMeetup,
      allowsDelivery: allowsDelivery,
      fulfillment: fulfillment,
      declineReason: declineReason,
    );
  }
}

/// HTTP client for the conversation and message endpoints. The server knows
/// the caller from the token, so no call carries a user id.
class MessageService {
  MessageService({http.Client? client}) : _client = client ?? apiClient();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Map<String, String> get _json => const {'Content-Type': 'application/json'};

  Future<List<ConversationRecord>> fetchConversations() async {
    final uri = Uri.parse('$_baseUrl/conversations');
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ConversationRecord.fromJson)
        .toList(growable: false);
  }

  Future<ConversationRecord> fetchConversation({required int conversationId}) async {
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId');
    final response = await sendRequest(() => _client.get(uri));
    return ConversationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Finds or creates the buyer's thread on a listing (the Message button).
  Future<ConversationRecord> openConversation({required int productId}) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/conversations'),
        headers: _json,
        body: jsonEncode({'product_id': productId}),
      ),
    );
    return ConversationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// The whole thread, or only messages newer than [afterId] (used to catch
  /// up after the chat socket reconnects).
  Future<List<MessageRecord>> fetchMessages({required int conversationId, String? afterId}) async {
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId/messages')
        .replace(queryParameters: afterId == null ? null : {'after': afterId});
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MessageRecord.fromJson)
        .toList(growable: false);
  }

  Future<MessageRecord> sendMessage({
    required int conversationId,
    required String content,
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
        headers: _json,
        body: jsonEncode({'content': content}),
      ),
    );
    return MessageRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  Future<void> markRead({required int conversationId}) async {
    final response = await sendRequest(
      () => _client.patch(Uri.parse('$_baseUrl/conversations/$conversationId/read')),
    );
    checkResponse(response);
  }

  void dispose() => _client.close();
}
