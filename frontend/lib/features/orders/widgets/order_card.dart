import 'package:flutter/material.dart';

import '../../../shared/widgets/kubo_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/data/order_service.dart';
import '../../chat/widgets/counter_offer_dialog.dart';

/// One row in an orders list: the listing thumbnail, what was ordered, how
/// it is being handed over, who the other party is, and the status.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.userId, this.onTap});

  final OrderRecord order;
  final int userId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = order.productImage;
    final role = order.isBuyer(userId) ? 'from' : 'to';

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: image == null
                      ? const ColoredBox(
                          color: AppColors.softBackground,
                          child: Icon(Icons.shopping_bag_outlined, color: AppColors.gray),
                        )
                      : KuboImage(image, width: 56, height: 56, errorIcon: Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.cropName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OrderStatusChip(order: order),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatAmount(order.quantity)} ${order.unit} × PHP ${formatAmount(order.price)} · '
                      'PHP ${formatAmount(order.total)}',
                      style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '#${order.id} · ${order.handoverLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gray, fontSize: 11),
                    ),
                    Text(
                      'Order $role ${order.counterpartyName(userId)}',
                      style: const TextStyle(color: AppColors.gray, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small status pill; green while the order is moving, grey once it is over.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final active = order.status.isOpen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.green : AppColors.softBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        order.statusLabel,
        style: TextStyle(
          color: active ? AppColors.white : AppColors.gray,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
