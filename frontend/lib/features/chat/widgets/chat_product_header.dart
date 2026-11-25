import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/message_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/order_service.dart';
import '../../../shared/widgets/kubo_image.dart';
import 'counter_offer_dialog.dart';

/// Sends a response to the offer on the table. [fulfillment] only goes with
/// a counter that changes the handover; [reason] only with a seller's
/// decline.
typedef OfferResponder = void Function(
  NegotiationAction action, {
  double? price,
  double? quantity,
  OfferFulfillment? fulfillment,
  DeclineReason? reason,
});

/// Listing card pinned above the thread, with the active offer card under
/// it: "Make offer" for a buyer with no open offer, the terms on the table
/// (price, quantity, and how the produce changes hands) with Accept /
/// Counter / Decline for whoever's turn it is, a status line while waiting
/// on the other side, and "View order" once accepted. Accepting locks the
/// terms and starts the order straight away.
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
    this.onRateOrder,
    this.onOpenListing,
  });

  /// Either side rates the other on a delivered order.
  final void Function(int orderId)? onRateOrder;

  final ConversationRecord conversation;
  final int userId;

  /// Disables the buttons while an offer request is in flight.
  final bool busy;

  final VoidCallback onMakeOffer;
  final OfferResponder onRespond;

  /// Buyer arranges pickup / delivery for an accepted offer from before the
  /// handover was part of the terms.
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
              // The thumbnail opens the listing too, not just the title.
              GestureDetector(
                onTap: onOpenListing,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: image == null
                        ? const ColoredBox(
                            color: AppColors.softBackground,
                            child: Icon(Icons.shopping_cart_outlined, color: AppColors.gray),
                          )
                        : KuboImage(image, width: 44, height: 44, errorIcon: Icons.shopping_cart_outlined),
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
            onRateOrder: onRateOrder,
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
    this.onRateOrder,
  });

  final ConversationRecord conversation;
  final int userId;
  final bool busy;
  final VoidCallback onMakeOffer;
  final OfferResponder onRespond;
  final VoidCallback onPlaceOrder;
  final void Function(int orderId) onOpenOrder;
  final void Function(int orderId)? onRateOrder;

  Future<void> _counter(BuildContext context) async {
    final offer = conversation.negotiation;
    if (offer == null) return;
    final terms = await showCounterOfferDialog(context, offer, bySeller: conversation.isSeller(userId));
    if (terms == null) return;
    onRespond(NegotiationAction.counter, price: terms.price, quantity: terms.quantity, fulfillment: terms.fulfillment);
  }

  // Accepting locks the terms and starts the order, so it is confirmed
  // with the terms spelled out first.
  Future<void> _accept(BuildContext context) async {
    final offer = conversation.negotiation;
    if (offer == null) return;
    final handover = offer.fulfillment;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accept this offer?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${formatAmount(offer.offeredQuantity)} ${offer.unit} of ${offer.cropName}'),
            Text('PHP ${formatAmount(offer.offeredPrice)} / ${offer.unit} · total PHP ${formatAmount(offer.total)}'),
            if (handover != null) Text(handover.label),
            const SizedBox(height: 12),
            Text(
              handover == null
                  ? 'These terms are final once accepted.'
                  : 'These terms are final once accepted, and the order starts right away.',
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Accept offer'),
          ),
        ],
      ),
    );
    if (confirmed == true) onRespond(NegotiationAction.accept);
  }

  // A seller says why before the decline goes through; a buyer turning a
  // counter down just declines.
  Future<void> _decline(BuildContext context) async {
    if (!conversation.isSeller(userId)) {
      onRespond(NegotiationAction.decline);
      return;
    }
    final reason = await showDeclineReasonDialog(context);
    if (reason == null) return;
    onRespond(NegotiationAction.decline, reason: reason);
  }

  // Calling off an agreed deal lets the other person down, so ask first.
  Future<void> _cancelDeal(BuildContext context) async {
    final quantity = '${formatAmount(conversation.offeredQuantity ?? 0)} ${conversation.unit}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this deal?'),
        content: Text(
          'The $quantity set aside for it goes back on the listing, and '
          '${conversation.counterpartyName(userId)} will be told the deal is off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep deal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Cancel deal'),
          ),
        ],
      ),
    );
    if (confirmed == true) onRespond(NegotiationAction.cancel);
  }

  @override
  Widget build(BuildContext context) {
    final thread = conversation;
    final status = thread.negotiationStatus;
    final termsLabel = thread.offeredPrice == null
        ? ''
        : 'PHP ${formatAmount(thread.offeredPrice!)} / ${thread.unit} '
            '× ${formatAmount(thread.offeredQuantity ?? 0)} ${thread.unit}';
    final handover = thread.fulfillment?.label;

    // Your move: accept, counter / edit, or decline.
    if (thread.isOfferTurnOf(userId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OfferTerms(
            heading: '${thread.isSeller(userId) ? 'Offer' : 'Counter'} on the table',
            terms: termsLabel,
            handover: handover,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SmallButton(
                label: 'Accept',
                filled: true,
                onTap: busy ? null : () => _accept(context),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'Counter / Edit',
                onTap: busy ? null : () => _counter(context),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'Decline',
                onTap: busy ? null : () => _decline(context),
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
            child: _OfferTerms(heading: 'Waiting for $waitingOn', terms: termsLabel, handover: handover),
          ),
          _SmallButton(
            label: 'Withdraw',
            onTap: busy ? null : () => onRespond(NegotiationAction.decline),
          ),
        ],
      );
    }

    // Ordered: the deal has moved on to fulfilment, on the locked terms.
    final orderId = thread.orderId;
    if (orderId != null) {
      final orderStatus = thread.orderStatus ?? OrderStatus.pending;
      final isPickup = thread.fulfillment?.isPickup ?? true;
      final statusLabel = switch (orderStatus) {
        OrderStatus.pending => 'in progress',
        OrderStatus.inTransit => isPickup ? 'ready for pickup' : 'out for delivery',
        OrderStatus.delivered => 'received',
        OrderStatus.cancelled => 'cancelled',
      };
      final rate = onRateOrder;
      final canRate = rate != null && thread.canReviewOrder(userId);
      return Row(
        children: [
          Expanded(
            child: _OfferTerms(heading: 'Order #$orderId $statusLabel', terms: termsLabel, handover: handover),
          ),
          if (canRate) ...[
            _SmallButton(label: 'Rate', filled: true, onTap: () => rate(orderId)),
            const SizedBox(width: 8),
          ],
          _SmallButton(
            label: 'View order',
            filled: orderStatus.isOpen && !canRate,
            onTap: () => onOpenOrder(orderId),
          ),
        ],
      );
    }

    // Accepted, not yet ordered: the buyer's move. The listing is holding
    // the quantity for this deal, so either side can still call it off.
    if (thread.isAwaitingOrder) {
      final canOrder = thread.canPlaceOrder(userId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canOrder
                ? 'Offer accepted · $termsLabel'
                : 'Offer accepted · waiting for ${thread.buyerName} to arrange pickup or delivery',
            style: const TextStyle(color: AppColors.gray, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (canOrder) ...[
                _SmallButton(label: 'Arrange pickup', filled: true, onTap: busy ? null : onPlaceOrder),
                const SizedBox(width: 8),
              ],
              _SmallButton(label: 'Cancel deal', onTap: busy ? null : () => _cancelDeal(context)),
            ],
          ),
        ],
      );
    }

    // Closed or no offer yet. A declined offer says why, when the seller did,
    // so the buyer knows what to change in the next one.
    final reason = thread.declineReason;
    final String? closedLabel = switch (status) {
      NegotiationStatus.accepted => 'Offer accepted · $termsLabel',
      NegotiationStatus.declined => thread.isDealCancelled
          ? 'Last deal cancelled'
          : reason == null
              ? 'Last offer declined'
              : 'Last offer declined: ${reason.label}',
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

/// The terms of the active offer: a heading (whose move it is, or the
/// order's state), the price and quantity, and the handover.
class _OfferTerms extends StatelessWidget {
  const _OfferTerms({required this.heading, required this.terms, this.handover});

  final String heading;
  final String terms;
  final String? handover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          terms.isEmpty ? heading : '$heading · $terms',
          style: const TextStyle(color: AppColors.gray, fontSize: 12),
        ),
        if (handover != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, size: 12, color: AppColors.green),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    handover!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
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
