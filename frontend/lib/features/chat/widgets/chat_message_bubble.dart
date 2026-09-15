import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/message_service.dart';
import 'counter_offer_dialog.dart';

/// One line of the thread. Text lines are grey bubbles with the sender's
/// avatar on the outside, as in the wireframe; offer events are the same
/// shape with a green border and a bold headline so the negotiation stands
/// out from the small talk around it.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message, required this.isMine});

  final MessageRecord message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubble = message.type.isOfferEvent ? _OfferBubble(message: message) : _TextBubble(message: message);
    final avatar = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: AppColors.black,
        child: const Icon(Icons.person, size: 14, color: AppColors.white),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: isMine ? 0 : 32, right: isMine ? 32 : 0, bottom: 3),
            child: Text(
              message.senderName,
              style: const TextStyle(color: AppColors.gray, fontSize: 10),
            ),
          ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[avatar, const SizedBox(width: 8)],
              Flexible(child: bubble),
              if (isMine) ...[const SizedBox(width: 8), avatar],
            ],
          ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message});

  final MessageRecord message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message.content,
        style: const TextStyle(color: AppColors.black, fontSize: 13, height: 1.35),
      ),
    );
  }
}

class _OfferBubble extends StatelessWidget {
  const _OfferBubble({required this.message});

  final MessageRecord message;

  @override
  Widget build(BuildContext context) {
    final price = message.offerPrice;
    final quantity = message.offerQuantity;
    final headline = switch (message.type) {
      MessageType.offer => 'Offer',
      MessageType.counter => 'Counter offer',
      MessageType.accepted => 'Offer accepted',
      MessageType.declined => 'Offer declined',
      MessageType.text => '',
    };
    final terms = price == null
        ? message.content
        : 'PHP ${formatAmount(price)}${quantity == null ? '' : ' × ${formatAmount(quantity)}'}';
    final total = price != null && quantity != null ? price * quantity : null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.green, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headline,
            style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            terms,
            style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          if (total != null)
            Text(
              'Total PHP ${formatAmount(total)}',
              style: const TextStyle(color: AppColors.gray, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
