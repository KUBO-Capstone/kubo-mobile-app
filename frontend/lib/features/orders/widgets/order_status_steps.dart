import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/order_service.dart';

/// Three-step progress line for an order: placed, on its way (dropped at
/// the bagsakan center or handed to a courier), received. A cancelled order
/// shows a single grey line instead of pretending it progressed.
class OrderStatusSteps extends StatelessWidget {
  const OrderStatusSteps({super.key, required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return Row(
        children: const [
          Icon(Icons.cancel_outlined, size: 18, color: AppColors.gray),
          SizedBox(width: 8),
          Text(
            'This order was cancelled.',
            style: TextStyle(color: AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final labels = [
      'Order placed',
      order.isMeetup ? 'At the bagsakan' : 'With the courier',
      order.isMeetup ? 'Picked up' : 'Delivered',
    ];
    final reached = switch (order.status) {
      OrderStatus.pending => 1,
      OrderStatus.inTransit => 2,
      OrderStatus.delivered => 3,
      OrderStatus.cancelled => 0,
    };

    // Top-aligned so a label that wraps to two lines does not pull its
    // circle out of line with the others; the connector sits at circle mid.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 11),
                color: i < reached ? AppColors.green : AppColors.border,
              ),
            ),
          _Step(label: labels[i], done: i < reached, current: i == reached - 1),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, required this.current});

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.green : AppColors.white,
            border: Border.all(color: done ? AppColors.green : AppColors.border, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: AppColors.white)
              : null,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 76,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: done ? AppColors.black : AppColors.gray,
              fontSize: 10,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
