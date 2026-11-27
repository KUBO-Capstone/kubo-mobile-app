import 'package:flutter/material.dart';
import '../../../shared/widgets/kubo_pressable.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/order_service.dart';
import '../../../shared/data/review_service.dart';
import '../../deals/screens/deal_celebration_page.dart';
import '../../../shared/widgets/kubo_star_rating.dart';
import '../../chat/screens/chat_page.dart';
import '../../reviews/screens/write_review_page.dart';
import '../../reviews/widgets/review_card.dart';
import '../../chat/widgets/counter_offer_dialog.dart';
import '../../market/widgets/market_price_table.dart' show formatDate;
import '../providers/order_controller.dart';
import '../widgets/order_card.dart';
import '../widgets/order_status_steps.dart';
import '../../../shared/widgets/kubo_image.dart';
import '../../../shared/widgets/kubo_photo_viewer.dart';
import 'hand_over_page.dart';

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

  // A page rather than a dialog: courier, tracking number and photos of the
  // produce. It stays open, with what was entered, if the request fails.
  Future<void> _ship(OrderRecord order) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => HandOverPage(
          order: order,
          uploadPhotos: _controller.uploadHandoverPhotos,
          ship: (details) => _controller.respond(
            OrderAction.ship,
            courierName: order.isMeetup ? null : details.courierName,
            trackingNumber: order.isMeetup ? null : details.trackingNumber,
            photos: details.photos,
          ),
        ),
      ),
    );
  }

  Future<void> _copyTracking(String trackingNumber) async {
    await Clipboard.setData(ClipboardData(text: trackingNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking number copied'), duration: Duration(seconds: 2)),
    );
  }

  // "Order received" is what closes the deal: only now is it celebrated, and
  // the review opens while the produce is in the buyer's hands.
  Future<void> _deliver(OrderRecord order) async {
    final confirmed = await _confirm(
      title: 'Order received?',
      body: 'Only confirm once you have the produce in hand. This closes the deal and cannot be undone.',
      action: 'Order Received',
    );
    if (!confirmed) return;
    final error = await _controller.respond(OrderAction.deliver);
    if (error != null) {
      _showError(error);
      return;
    }
    final delivered = _controller.order;
    final userId = _controller.userId ?? 0;
    if (!mounted || delivered == null) return;

    // Marked before the screen opens, so the chat does not show it again.
    final negotiations = NegotiationService();
    negotiations
        .markCelebrated(negotiationId: delivered.negotiationId)
        .catchError((Object error) => debugPrint('Could not record the deal celebration: $error'))
        .whenComplete(negotiations.dispose);

    final action = await Navigator.of(context).push<DealCelebrationAction>(
      MaterialPageRoute<DealCelebrationAction>(
        fullscreenDialog: true,
        builder: (_) => DealCelebrationPage(
          isSeller: false,
          counterpartyName: delivered.sellerName,
          cropName: delivered.cropName,
          quantity: delivered.quantity,
          unit: delivered.unit,
          price: delivered.price,
          canReview: delivered.canReview(userId),
        ),
      ),
    );
    if (!mounted) return;
    if (action == DealCelebrationAction.writeReview) await _writeReview(delivered);
  }

  Future<void> _writeReview(OrderRecord order, {int initialRating = 0}) async {
    final review = await Navigator.of(context).push<ReviewRecord>(
      MaterialPageRoute<ReviewRecord>(
        builder: (_) => WriteReviewPage(order: order, initialRating: initialRating),
      ),
    );
    if (review == null || !mounted) return;
    _controller.changed = true;
    await _controller.load();
  }

  Future<void> _cancel(OrderRecord order) async {
    final confirmed = await _confirm(
      title: 'Cancel this order?',
      body: 'The ${formatAmount(order.quantity)} ${order.unit} go back on the listing and '
          '${order.counterpartyName(_controller.userId ?? 0)} will see it was cancelled.',
      action: 'Cancel Order',
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
            _Row('Agreed Price', 'PHP ${formatAmount(order.price)} / ${order.unit}'),
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
              // Agreed in the offer; older orders name it when shipped, or in the chat.
              _Row('Courier', order.courierName ?? (order.status == OrderStatus.pending ? 'Not booked yet' : 'See chat')),
              if ((order.trackingNumber ?? '').isNotEmpty)
                _TrackingRow(trackingNumber: order.trackingNumber!, onCopy: () => _copyTracking(order.trackingNumber!))
              else
                _Row('Tracking no.', order.status == OrderStatus.pending ? '—' : 'See chat'),
            ],
            if (order.shippedAt != null)
              _Row(order.isMeetup ? 'Dropped Off' : 'Shipped', formatDate(order.shippedAt)),
            if (order.handoverPhotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                order.isMeetup ? 'Photos at Drop-off' : 'Photos at Handover',
                style: const TextStyle(color: AppColors.gray, fontSize: 12),
              ),
              const SizedBox(height: 6),
              _HandoverPhotos(photos: order.handoverPhotos),
            ],
          ],
        ),
        if (order.status == OrderStatus.delivered) ...[
          const SizedBox(height: 12),
          _ReviewPanel(
            order: order,
            userId: userId,
            onRate: (stars) => _writeReview(order, initialRating: stars),
          ),
        ],
        const SizedBox(height: 24),
        ..._buildActions(order, userId),
        if (widget.openChat) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _openChat(order),
            style: TextButton.styleFrom(foregroundColor: AppColors.green),
            child: Text('Open Chat with ${order.counterpartyName(userId)}'),
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
        label: order.isMeetup ? 'Mark as Dropped Off at Center' : 'Hand Over to Courier',
        onTap: busy ? null : () => _ship(order),
      ));
    } else if (order.canDeliver(userId)) {
      buttons.add(_Primary(
        label: 'Order Received',
        onTap: busy ? null : () => _deliver(order),
      ));
      buttons.add(const SizedBox(height: 6));
      buttons.add(const Text(
        'Tap once you have the produce. Then you can rate the seller.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.gray, fontSize: 11),
      ));
    } else if (order.status == OrderStatus.pending) {
      buttons.add(_Hint(order.isBuyer(userId)
          ? '${order.sellerName} is preparing your order for ${order.isMeetup ? 'drop-off at ${order.centerName ?? 'the center'}' : order.handoverLabel.toLowerCase()}.'
          : 'Once you drop it off or hand it to the courier, mark it here.'));
    } else if (order.status == OrderStatus.inTransit) {
      buttons.add(_Hint(order.isMeetup
          ? 'Waiting for ${order.buyerName} to pick it up and confirm.'
          : 'Waiting for ${order.buyerName} to confirm the order arrived.'));
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
        child: const Text('Cancel Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ));
    }
    return buttons;
  }
}

/// Delivered orders: a prompt to rate the other side, then both reviews.
class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.order, required this.userId, required this.onRate});

  final OrderRecord order;
  final int userId;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final other = order.counterpartyName(userId);
    final mine = order.myReview;
    final theirs = order.theirReview;
    return _Panel(
      title: 'Reviews',
      children: [
        if (mine == null) ...[
          Text(
            order.isBuyer(userId) ? 'How was your order from $other?' : 'How was dealing with $other?',
            style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          KuboStarRatingInput(value: 0, size: 36, onChanged: onRate),
          const SizedBox(height: 2),
          const Center(
            child: Text('Tap a star to rate', style: TextStyle(color: AppColors.gray, fontSize: 11)),
          ),
        ] else ...[
          const Text('Your Review', style: TextStyle(color: AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ReviewCard(review: mine, showProduct: false, margin: EdgeInsets.zero),
        ],
        const SizedBox(height: 12),
        if (theirs != null) ...[
          Text("$other's review of you", style: const TextStyle(color: AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ReviewCard(review: theirs, showProduct: false, margin: EdgeInsets.zero),
        ] else
          Text(
            '$other has not reviewed you yet.',
            style: const TextStyle(color: AppColors.gray, fontSize: 12),
          ),
      ],
    );
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

/// The tracking number with a copy button, so it can go straight into the
/// courier's app or site.
class _TrackingRow extends StatelessWidget {
  const _TrackingRow({required this.trackingNumber, required this.onCopy});

  final String trackingNumber;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          const SizedBox(
            width: 100,
            child: Text('Tracking no.', style: TextStyle(color: AppColors.gray, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(
              trackingNumber,
              style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ),
          IconButton(
            tooltip: 'Copy tracking number',
            onPressed: onCopy,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.green),
          ),
        ],
      ),
    );
  }
}

/// The seller's handover photos; tap one to see it full screen.
class _HandoverPhotos extends StatefulWidget {
  const _HandoverPhotos({required this.photos});

  final List<String> photos;

  @override
  State<_HandoverPhotos> createState() => _HandoverPhotosState();
}

class _HandoverPhotosState extends State<_HandoverPhotos> {
  static const double _size = 72;

  // Tells these photos apart from other galleries in the stack.
  final Object _gallery = Object();

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final decodeWidth = kuboDecodeWidthFor(context, width: _size, height: _size);
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Semantics(
          button: true,
          label: 'Handover photo ${index + 1} of ${photos.length}',
          onTapHint: 'view full screen',
          excludeSemantics: true,
          child: KuboPressable(
            onTap: () => KuboPhotoViewer.open(
              context,
              photos: photos,
              initialIndex: index,
              heroTagFor: (i) => KuboPhotoHeroTag(_gallery, i),
              placeholderFor: (i) => kuboImageProvider(photos[i], decodeWidth: decodeWidth),
            ),
            child: Hero(
              tag: KuboPhotoHeroTag(_gallery, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: KuboImage(photos[index], width: _size, height: _size, decodeWidth: decodeWidth),
              ),
            ),
          ),
        ),
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
