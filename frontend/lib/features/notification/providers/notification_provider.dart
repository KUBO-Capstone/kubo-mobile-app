import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../../../shared/data/api_request.dart';

/// What the notifications page can narrow the list to.
enum NotificationFilter {
  all('All'),
  unread('Unread'),
  messages('Messages'),
  offers('Offers'),
  orders('Orders'),
  reviews('Reviews');

  const NotificationFilter(this.label);

  final String label;

  bool matches(NotificationRecord notification) => switch (this) {
        NotificationFilter.all => true,
        NotificationFilter.unread => !notification.isRead,
        _ => notification.category == this,
      };
}

class NotificationRecord {
  const NotificationRecord({
    this.id,
    this.isRead = true,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.sender,
    required this.recipient,
    this.product,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    final createdAtText = json['created_at']?.toString() ?? '';
    final hasTimeZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(createdAtText);
    final createdAt = DateTime.tryParse(hasTimeZone ? createdAtText : '${createdAtText}Z');
    return NotificationRecord(
      id: (json['notification_id'] as num?)?.toInt(),
      isRead: json['is_read'] != false,
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      createdAt: createdAt?.toLocal(),
      sender: json['sender'] is Map<String, dynamic>
          ? PersonDetails.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      recipient: PersonDetails.fromJson(
        (json['recipient'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      product: json['product'] is Map<String, dynamic>
          ? ProductDetails.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  final int? id;

  /// False until the person opens it or taps Mark All as Read.
  final bool isRead;
  final String title;
  final String message;
  final DateTime? createdAt;

  /// Which filter this belongs under, from the title the server gives it
  /// (see notificationTitle in backend/src/services/chat.service.ts).
  NotificationFilter get category => switch (title) {
        'New Offer' || 'Offer Update' => NotificationFilter.offers,
        'Order Update' || 'Delivered' => NotificationFilter.orders,
        'New Review' => NotificationFilter.reviews,
        // Order events from before they had their own title.
        _ when RegExp(r'^(Order #|Placed order|Received order|Picked up order|Shipped order)').hasMatch(message) =>
          NotificationFilter.orders,
        _ => NotificationFilter.messages,
      };

  NotificationRecord asRead() => NotificationRecord(
        id: id,
        isRead: true,
        title: title,
        message: message,
        createdAt: createdAt,
        sender: sender,
        recipient: recipient,
        product: product,
      );
  final PersonDetails? sender;
  final PersonDetails recipient;
  final ProductDetails? product;

  String get displayMessage {
    const maxLength = 96;
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength).trimRight()}...';
  }

  String get date {
    final value = createdAt;
    if (value == null) return '';
    return '${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}/${value.year}';
  }

  String get time {
    final value = createdAt;
    if (value == null) return '';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class PersonDetails {
  const PersonDetails({required this.name, required this.email});

  factory PersonDetails.fromJson(Map<String, dynamic> json) {
    return PersonDetails(
      name: json['name']?.toString() ?? 'Unknown user',
      email: json['email']?.toString() ?? '',
    );
  }

  final String name;
  final String email;
}

class ProductDetails {
  const ProductDetails({
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.status,
    this.image,
  });

  factory ProductDetails.fromJson(Map<String, dynamic> json) {
    return ProductDetails(
      name: json['name']?.toString() ?? 'Product',
      category: json['category']?.toString() ?? 'Produce',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      image: resolveMediaUrl(json['image']?.toString()),
    );
  }

  final String name;
  final String category;
  final double price;
  final double quantity;
  final String unit;
  final String status;
  final String? image;
}

class NotificationProvider {
  NotificationProvider({http.Client? client}) : _client = client ?? apiClient();

  final http.Client _client;

  Future<List<NotificationRecord>> fetchNotifications() async {
    final response = await sendRequest(
      () => _client.get(Uri.parse('${ApiConfig.baseUrl}/notifications')),
    );
    final data = readData(response) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(NotificationRecord.fromJson)
        .toList(growable: false);
  }

  Future<int> fetchUnreadCount() async {
    final response = await sendRequest(
      () => _client.get(Uri.parse('${ApiConfig.baseUrl}/notifications/unread-count')),
    );
    final data = readData(response) as Map<String, dynamic>;
    return (data['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int notificationId) async {
    final response = await sendRequest(
      () => _client.patch(Uri.parse('${ApiConfig.baseUrl}/notifications/$notificationId/read')),
    );
    checkResponse(response);
  }

  Future<void> markAllRead() async {
    final response = await sendRequest(
      () => _client.patch(Uri.parse('${ApiConfig.baseUrl}/notifications/read')),
    );
    checkResponse(response);
  }

  void dispose() => _client.close();
}
