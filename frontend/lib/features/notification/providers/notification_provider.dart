import 'package:http/http.dart' as http;

import '../../../core/constants/api_config.dart';
import '../../../shared/data/api_request.dart';

class NotificationRecord {
  const NotificationRecord({
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

  final String title;
  final String message;
  final DateTime? createdAt;
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
      image: json['image']?.toString(),
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

  void dispose() => _client.close();
}
