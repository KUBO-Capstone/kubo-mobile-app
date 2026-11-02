import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/order_service.dart';

/// What the seller enters when handing a courier order over. Either can be
/// empty: the seller may send the tracking link or details in the chat.
class CourierDetails {
  const CourierDetails({required this.courierName, required this.trackingNumber});

  final String courierName;
  final String trackingNumber;
}

/// Seller marks the order as on its way. A meetup order is a plain confirm
/// ("I dropped it at the center"); a courier order optionally takes the
/// courier and tracking number, which the buyer then sees on the order page.
///
/// Returns null when dismissed; [CourierDetails] for courier; an empty
/// details object for a confirmed meetup drop-off.
Future<CourierDetails?> showShipOrderDialog(BuildContext context, OrderRecord order) {
  if (order.isMeetup) {
    return showDialog<CourierDetails>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as dropped off?'),
        content: Text(
          'This tells ${order.buyerName} the produce is waiting at '
          '${order.centerName ?? 'the bagsakan center'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.of(dialogContext).pop(
              const CourierDetails(courierName: '', trackingNumber: ''),
            ),
            child: const Text('Dropped off'),
          ),
        ],
      ),
    );
  }
  return showDialog<CourierDetails>(
    context: context,
    builder: (_) => const _CourierDialog(),
  );
}

class _CourierDialog extends StatefulWidget {
  const _CourierDialog();

  @override
  State<_CourierDialog> createState() => _CourierDialogState();
}

class _CourierDialogState extends State<_CourierDialog> {
  final _courier = TextEditingController();
  final _tracking = TextEditingController();

  @override
  void dispose() {
    _courier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(CourierDetails(
      courierName: _courier.text.trim(),
      trackingNumber: _tracking.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hand over to courier'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Optional. The buyer will see these on the order. You can also '
            'send the tracking link or details in the chat.',
            style: TextStyle(color: AppColors.gray, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _courier,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Courier',
              hintText: 'e.g. J&T Express, LBC, Lalamove',
              border: OutlineInputBorder(),
              isDense: true,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tracking,
            textCapitalization: TextCapitalization.characters,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Tracking number',
              border: OutlineInputBorder(),
              isDense: true,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: _submit,
          child: const Text('Mark as shipped'),
        ),
      ],
    );
  }
}
