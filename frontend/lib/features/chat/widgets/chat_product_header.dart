import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/message_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/order_service.dart';
import 'counter_offer_dialog.dart';

/// Listing card pinned above the thread, with the offer control the
/// wireframe puts in its corner: "Make offer" for a buyer with no open
/// offer, Accept / Counter / Decline for whoever's turn it is, a status
/// line while waiting on the other side, then "Arrange pickup" once the
/// offer is accepted and "View order" once it has been ordered.
class ChatProductHeader extends StatelessWidget {
  const ChatProductHeader({
    super.key,
    required this.conversation,
    required this.userId,
    required this.busy,
    required this.onMakeOffer,
    required this.onRespond,
    required this.onPlaceOrder,
    required this.onOpenOrder,
    this.onOpenListing,
  });

  final ConversationRecord conversation;
  final int userId;

  /// Disables the buttons while an offer request is in flight.
  final bool busy;

  final VoidCallback onMakeOffer;
  final void Function(NegotiationAction action, {double? price, double? quantity}) onRespond;

  /// Buyer arranges pickup / delivery for the accepted offer.
  final VoidCallback onPlaceOrder;

  /// Either side opens the order placed on this thread.
  final void Function(int orderId) onOpenOrder;
  final VoidCallback? onOpenListing;

  @override
  Widget build(BuildContext context) {
    final thread = conversation;
    final image = thread.productImage;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onOpenListing,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.cropName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PHP ${formatAmount(thread.basePrice)} / ${thread.unit}',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: image == null
                      ? const ColoredBox(
                          color: AppColors.softBackground,
                          child: Icon(Icons.shopping_cart_outlined, color: AppColors.gray),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AppColors.softBackground,
                            child: Icon(Icons.shopping_cart_outlined, color: AppColors.gray),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OfferControl(
            conversation: thread,
            userId: userId,
            busy: busy,
            onMakeOffer: onMakeOffer,
            onRespond: onRespond,
            onPlaceOrder: onPlaceOrder,
            onOpenOrder: onOpenOrder,
          ),
        ],
      ),
    );
  }
}

class _OfferControl extends StatelessWidget {
  const _OfferControl({
    required this.conversation,
    required this.userId,
    required this.busy,
    required this.onMakeOffer,
    required this.onRespond,
    required this.onPlaceOrder,
    required this.onOpenOrder,
  });

  final ConversationRecord conversation;
  final int userId;
  final bool busy;
  final VoidCallback onMakeOffer;
  final void Function(NegotiationAction action, {double? price, double? quantity}) onRespond;
  final VoidCallback onPlaceOrder;
  final void Function(int orderId) onOpenOrder;

  Future<void> _counter(BuildContext context) async {
    final offer = conversation.negotiation;
    if (offer == null) return;
    final terms = await showCounterOfferDialog(context, offer);
    if (terms == null) return;
    onRespond(NegotiationAction.counter, price: terms.price, quantity: terms.quantity);
  }

  @override
  Widget build(BuildContext context) {
    final thread = conversation;
    final status = thread.negotiationStatus;
    final termsLabel = thread.offeredPrice == null
        ? ''
        : 'PHP ${formatAmount(thread.offeredPrice!)} / ${thread.unit} '
            '× ${formatAmount(thread.offeredQuantity ?? 0)} ${thread.unit}';

    // Your move: accept, counter, or decline.
    if (thread.isOfferTurnOf(userId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${thread.isSeller(userId) ? 'Offer' : 'Counter'} on the table: $termsLabel',
            style: const TextStyle(color: AppColors.gray, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SmallButton(
                label: 'Accept',
                filled: true,
                onTap: busy ? null : () => onRespond(NegotiationAction.accept),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'Counter',
                onTap: busy ? null : () => _counter(context),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'Decline',
                onTap: busy ? null : () => onRespond(NegotiationAction.decline),
              ),
            ],
          ),
        ],
      );
    }

    // Their move: say so, and let the sender withdraw.
    if (thread.hasOpenOffer) {
      final waitingOn = thread.isSeller(userId) ? thread.buyerName : thread.sellerName;
      return Row(
        children: [
          Expanded(
            child: Text(
              'Waiting for $waitingOn · $termsLabel',
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
          ),
          _SmallButton(
            label: 'Withdraw',
            onTap: busy ? null : () => onRespond(NegotiationAction.decline),
          ),
        ],
      );
    }

    // Ordered: the deal has moved on to fulfilment.
    final orderId = thread.orderId;
    if (orderId != null) {
      final orderStatus = thread.orderStatus ?? OrderStatus.pending;
      final statusLabel = switch (orderStatus) {
        OrderStatus.pending => 'placed',
        OrderStatus.inTransit => 'on its way',
        OrderStatus.delivered => 'completed',
        OrderStatus.cancelled => 'cancelled',
      };
      return Row(
        children: [
          Expanded(
            child: Text(
              'Order #$orderId $statusLabel · $termsLabel',
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
          ),
          _SmallButton(
            label: 'View order',
            filled: orderStatus.isOpen,
            onTap: () => onOpenOrder(orderId),
          ),
        ],
      );
    }

    // Accepted, not yet ordered: the buyer's move.
    if (thread.isAwaitingOrder) {
      if (thread.canPlaceOrder(userId)) {
        return Row(
          children: [
            Expanded(
              child: Text(
                'Offer accepted · $termsLabel',
                style: const TextStyle(color: AppColors.gray, fontSize: 12),
              ),
            ),
            _SmallButton(label: 'Arrange pickup', filled: true, onTap: busy ? null : onPlaceOrder),
          ],
        );
      }
      return Text(
        'Offer accepted · waiting for ${thread.buyerName} to arrange pickup or delivery',
        style: const TextStyle(color: AppColors.gray, fontSize: 12),
      );
    }

    // Closed or no offer yet.
    final String? closedLabel = switch (status) {
      NegotiationStatus.accepted => 'Offer accepted · $termsLabel',
      NegotiationStatus.declined => 'Last offer declined',
      _ => null,
    };
    if (thread.canMakeOffer(userId)) {
      return Row(
        children: [
          if (closedLabel != null)
            Expanded(
              child: Text(
                closedLabel,
                style: const TextStyle(color: AppColors.gray, fontSize: 12),
              ),
            )
          else
            const Spacer(),
          _SmallButton(
            label: status == NegotiationStatus.declined ? 'Make new offer' : 'Make offer',
            filled: true,
            onTap: busy ? null : onMakeOffer,
          ),
        ],
      );
    }
    return Text(
      closedLabel ??
          (thread.isProductAvailable
              ? 'No offer yet.'
              : 'This listing is no longer available.'),
      style: const TextStyle(color: AppColors.gray, fontSize: 12),
    );
  }
}

/// Compact pill button; filled green for the primary action, outlined otherwise.
class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
    if (filled) {
      return FilledButton(
        onPressed: onTap,
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(AppColors.green),
          foregroundColor: const WidgetStatePropertyAll(AppColors.white),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: style.copyWith(
        foregroundColor: const WidgetStatePropertyAll(AppColors.black),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
      child: Text(label),
    );
  }
}
