import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_config.dart';
import 'api_request.dart';
import 'negotiation_service.dart';

/// Kind of chat line. Mirrors the `messages.message_type` CHECK constraint.
///
/// [text] is a typed message; the rest are offer events the server writes
/// when an offer is made, countered, accepted or declined, so the thread is
/// also the negotiation history.
enum MessageType {
  text,
  offer,
  counter,
  accepted,
  declined;

  static MessageType parse(String? raw) => MessageType.values.firstWhere(
        (type) => type.name == raw,
        orElse: () => MessageType.text,
      );

  bool get isOfferEvent => this != text;
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
    this.offerPrice,
    this.offerQuantity,
    this.readAt,
  });

  factory MessageRecord.fromJson(Map<String, dynamic> json) {
    return MessageRecord(
      id: (json['message_id'] as num).toInt(),
      conversationId: (json['conversation_id'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      senderName: json['sender_name']?.toString() ?? 'User',
      content: json['content']?.toString() ?? '',
      type: MessageType.parse(json['message_type']?.toString()),
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? ''),
      negotiationId: (json['negotiation_id'] as num?)?.toInt(),
      offerPrice: (json['offer_price'] as num?)?.toDouble(),
      offerQuantity: (json['offer_quantity'] as num?)?.toDouble(),
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
    );
  }

  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime? sentAt;
  final int? negotiationId;
  final double? offerPrice;
  final double? offerQuantity;
  final DateTime? readAt;

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
    required this.sellerLocation,
    required this.unreadCount,
    this.productImage,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAt,
    this.negotiationId,
    this.negotiationStatus,
    this.offeredPrice,
    this.offeredQuantity,
  });

  factory ConversationRecord.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['negotiation_status']?.toString();
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
      productImage: json['product_image']?.toString(),
      sellerLocation: json['seller_location']?.toString() ?? 'Philippines',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message']?.toString(),
      lastMessageType: json['last_message_type'] == null
          ? null
          : MessageType.parse(json['last_message_type'].toString()),
      lastMessageAt: DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
      negotiationId: (json['negotiation_id'] as num?)?.toInt(),
      negotiationStatus: rawStatus == null ? null : NegotiationStatus.parse(rawStatus),
      offeredPrice: (json['offered_price'] as num?)?.toDouble(),
      offeredQuantity: (json['offered_quantity'] as num?)?.toDouble(),
    );
  }

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
  final String? productImage;
  final String sellerLocation;
  final int unreadCount;
  final String? lastMessage;
  final MessageType? lastMessageType;
  final DateTime? lastMessageAt;

  /// Latest offer on this thread, open or closed. Null before any offer.
  final int? negotiationId;
  final NegotiationStatus? negotiationStatus;
  final double? offeredPrice;
  final double? offeredQuantity;

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
  /// last one is closed (or there is none) and the listing is still up.
  bool canMakeOffer(int userId) =>
      isBuyer(userId) && !hasOpenOffer && isProductAvailable;

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
    );
  }
}

/// HTTP client for the conversation and message endpoints.
///
/// KNOWN DEBT: `user_id` / `sender_id` / `buyer_id` go in the request because
/// there is no auth token yet; drop them here when Phase 2 lands.
class MessageService {
  MessageService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl => ApiConfig.baseUrl;
  final http.Client _client;

  Map<String, String> get _json => const {'Content-Type': 'application/json'};

  Future<List<ConversationRecord>> fetchConversations({required int userId}) async {
    final uri = Uri.parse('$_baseUrl/conversations').replace(queryParameters: {'user_id': '$userId'});
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ConversationRecord.fromJson)
        .toList(growable: false);
  }

  Future<ConversationRecord> fetchConversation({required int conversationId, required int userId}) async {
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId').replace(queryParameters: {'user_id': '$userId'});
    final response = await sendRequest(() => _client.get(uri));
    return ConversationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  /// Finds or creates the buyer's thread on a listing (the Message button).
  Future<ConversationRecord> openConversation({required int buyerId, required int productId}) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/conversations'),
        headers: _json,
        body: jsonEncode({'buyer_id': buyerId, 'product_id': productId}),
      ),
    );
    return ConversationRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  Future<List<MessageRecord>> fetchMessages({required int conversationId, required int userId}) async {
    final uri = Uri.parse('$_baseUrl/conversations/$conversationId/messages')
        .replace(queryParameters: {'user_id': '$userId'});
    final response = await sendRequest(() => _client.get(uri));
    return (readData(response) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MessageRecord.fromJson)
        .toList(growable: false);
  }

  Future<MessageRecord> sendMessage({
    required int conversationId,
    required int senderId,
    required String content,
  }) async {
    final response = await sendRequest(
      () => _client.post(
        Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
        headers: _json,
        body: jsonEncode({'sender_id': senderId, 'content': content}),
      ),
    );
    return MessageRecord.fromJson(readData(response) as Map<String, dynamic>);
  }

  Future<void> markRead({required int conversationId, required int userId}) async {
    final response = await sendRequest(
      () => _client.patch(
        Uri.parse('$_baseUrl/conversations/$conversationId/read'),
        headers: _json,
        body: jsonEncode({'user_id': userId}),
      ),
    );
    checkResponse(response);
  }

  void dispose() => _client.close();
}
