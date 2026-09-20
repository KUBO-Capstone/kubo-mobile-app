import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/order_service.dart';
import '../../chat/screens/chat_page.dart';
import '../../chat/widgets/counter_offer_dialog.dart';
import '../../market/widgets/market_price_table.dart' show formatDate;
import '../providers/order_controller.dart';
import '../widgets/order_card.dart';
import '../widgets/order_status_steps.dart';
import '../widgets/ship_order_dialog.dart';

/// One order: what was agreed, how it changes hands, where it stands, and
/// the one action the signed-in side can take next. Pops `true` when the
/// status changed so the caller reloads.
class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.orderId, this.openChat = true});

  static const routeName = '/order';

  final int orderId;

  /// Hide the "Open chat" link when this page was pushed from the thread
  /// itself, so the user does not stack the same chat twice.
  final bool openChat;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final OrderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OrderController(orderId: widget.orderId);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showError(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _ship(OrderRecord order) async {
    final details = await showShipOrderDialog(context, order);
    if (details == null) return;
    _showError(await _controller.respond(
      OrderAction.ship,
      courierName: order.isMeetup ? null : details.courierName,
      trackingNumber: order.isMeetup ? null : details.trackingNumber,
    ));
  }

  Future<void> _deliver(OrderRecord order) async {
    final confirmed = await _confirm(
      title: order.isMeetup ? 'Picked it up?' : 'Received it?',
      body: 'This closes the order. Only confirm once you have the produce.',
      action: order.isMeetup ? 'Picked up' : 'Received',
    );
    if (!confirmed) return;
    _showError(await _controller.respond(OrderAction.deliver));
  }

  Future<void> _cancel(OrderRecord order) async {
    final confirmed = await _confirm(
      title: 'Cancel this order?',
      body: 'The ${formatAmount(order.quantity)} ${order.unit} go back on the listing and '
          '${order.counterpartyName(_controller.userId ?? 0)} will see it was cancelled.',
      action: 'Cancel order',
    );
    if (!confirmed) return;
    _showError(await _controller.respond(OrderAction.cancel));
  }

  Future<bool> _confirm({required String title, required String body, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openChat(OrderRecord order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatPage(conversationId: order.conversationId)),
    );
    if (mounted) _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_controller.changed);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Scaffold(
            backgroundColor: AppColors.white,
            appBar: AppBar(
              backgroundColor: AppColors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
                onPressed: () => Navigator.of(context).pop(_controller.changed),
              ),
              title: Text(
                'ORDER #${widget.orderId}',
                style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
            ),
            body: _buildBody(),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final order = _controller.order;
    if (_controller.isLoading && order == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    final error = _controller.errorMessage;
    if (order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error ?? 'Order not found.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray)),
              const SizedBox(height: 12),
              TextButton(onPressed: _controller.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final userId = _controller.userId ?? 0;
    final isBuyer = order.isBuyer(userId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.cropName,
                style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            OrderStatusChip(order: order),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isBuyer ? 'Sold by ${order.sellerName}' : 'Bought by ${order.buyerName}',
          style: const TextStyle(color: AppColors.gray, fontSize: 12),
        ),
        const SizedBox(height: 20),
        OrderStatusSteps(order: order),
        const SizedBox(height: 24),
        _Panel(
          title: 'Order',
          children: [
            _Row('Quantity', '${formatAmount(order.quantity)} ${order.unit}'),
            _Row('Agreed price', 'PHP ${formatAmount(order.price)} / ${order.unit}'),
            _Row('Total', 'PHP ${formatAmount(order.total)}', bold: true),
            _Row('Placed', formatDate(order.orderDate)),
          ],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: order.isMeetup ? 'Pickup' : 'Delivery',
          children: [
            if (order.isMeetup) ...[
              _Row('Center', order.centerName ?? '—'),
              _Row(
                'Address',
                [
                  if ((order.centerAddress ?? '').isNotEmpty) order.centerAddress!,
                  if ((order.centerLocation ?? '').isNotEmpty) order.centerLocation!,
                ].join(', '),
              ),
            ] else ...[
              _Row('Method', 'Courier'),
              _Row('Courier', order.courierName ?? 'Not booked yet'),
              _Row('Tracking no.', order.trackingNumber ?? '—'),
            ],
          ],
        ),
        const SizedBox(height: 24),
        ..._buildActions(order, userId),
        if (widget.openChat) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openChat(order),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: Text('Open chat with ${order.counterpartyName(userId)}'),
            style: TextButton.styleFrom(foregroundColor: AppColors.green),
          ),
        ],
      ],
    );
  }

  // One primary action per side per status, plus cancel while pending.
  List<Widget> _buildActions(OrderRecord order, int userId) {
    final busy = _controller.isBusy;
    final buttons = <Widget>[];

    if (order.canShip(userId)) {
      buttons.add(_Primary(
        label: order.isMeetup ? 'Mark as dropped off at center' : 'Hand over to courier',
        onTap: busy ? null : () => _ship(order),
      ));
    } else if (order.canDeliver(userId)) {
      buttons.add(_Primary(
        label: order.isMeetup ? 'I picked it up' : 'I received it',
        onTap: busy ? null : () => _deliver(order),
      ));
    } else if (order.status == OrderStatus.pending) {
      buttons.add(_Hint(order.isBuyer(userId)
          ? 'Waiting for ${order.sellerName} to ${order.isMeetup ? 'drop it off at the center' : 'book a courier'}.'
          : 'Once you drop it off, mark it here.'));
    } else if (order.status == OrderStatus.inTransit) {
      buttons.add(_Hint(order.isMeetup
          ? 'Waiting for ${order.buyerName} to pick it up.'
          : 'Waiting for ${order.buyerName} to confirm delivery.'));
    }

    if (order.canCancel(userId)) {
      buttons.add(const SizedBox(height: 8));
      buttons.add(OutlinedButton(
        onPressed: busy ? null : () => _cancel(order),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Cancel order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ));
    }
    return buttons;
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, size: 16, color: AppColors.gray),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.gray, fontSize: 12))),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                color: AppColors.black,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
