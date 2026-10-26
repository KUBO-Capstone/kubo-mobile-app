import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.notification});

  final NotificationRecord notification;

  @override
  Widget build(BuildContext context) {
    final product = notification.product;
    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        backgroundColor: AppColors.softBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'NOTIFICATION DETAILS',
          style: TextStyle(
            color: AppColors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          _section('Notification', [
            _detailRow('Title', notification.title),
            _detailRow('Message', notification.message),
            _detailRow('Date', '${notification.date}, ${notification.time}'),
          ]),
          const SizedBox(height: 12),
          _section('People', [
            _detailRow('Sender', notification.sender?.name ?? 'Deleted user'),
            if (notification.sender?.email.isNotEmpty ?? false)
              _detailRow('Sender email', notification.sender!.email),
            _detailRow('Recipient', notification.recipient.name),
            if (notification.recipient.email.isNotEmpty)
              _detailRow('Recipient email', notification.recipient.email),
          ]),
          if (product != null) ...[
            const SizedBox(height: 12),
            _productSection(product),
          ],
        ],
      ),
    );
  }

  Widget _productSection(ProductDetails product) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(image: product.image),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _detailRow('Category', product.category),
                _detailRow('Price', 'PHP ${product.price.toStringAsFixed(2)} / ${product.unit}'),
                _detailRow('Available', '${product.quantity} ${product.unit}'),
                _detailRow('Status', product.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String heading, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.black, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    final source = image;
    if (source == null || source.isEmpty) {
      return _placeholder();
    }
    return Image.network(
      source,
      height: 190,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 190,
      width: double.infinity,
      color: AppColors.softBackground,
      alignment: Alignment.center,
      child: const Icon(Icons.shopping_basket_outlined, color: AppColors.gray, size: 54),
    );
  }
}