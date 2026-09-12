import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/negotiation_service.dart';
import '../providers/offers_controller.dart';
import 'counter_offer_dialog.dart';

/// Body of the Market tab: the signed-in user's negotiations, split into offers
/// they received on their listings and offers they sent to other farmers.
class OffersView extends StatefulWidget {
  const OffersView({super.key});

  @override
  State<OffersView> createState() => _OffersViewState();
}

class _OffersViewState extends State<OffersView> {
  late final OffersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OffersController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _respond(
    NegotiationRecord offer,
    NegotiationAction action, {
    double? price,
    double? quantity,
  }) async {
    final error = await _controller.respond(offer, action, price: price, quantity: quantity);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final label = switch (action) {
      NegotiationAction.accept => 'Offer accepted.',
      NegotiationAction.decline => 'Offer declined.',
      NegotiationAction.counter => 'Counter sent.',
    };
    messenger.showSnackBar(SnackBar(content: Text(label)));
  }

  Future<void> _counter(NegotiationRecord offer) async {
    final terms = await showCounterOfferDialog(context, offer);
    if (terms == null) return;
    await _respond(offer, NegotiationAction.counter, price: terms.price, quantity: terms.quantity);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Offers',
                  style: TextStyle(color: AppColors.black, fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SideToggle(
                  side: _controller.side,
                  receivedCount: _controller.received.length,
                  sentCount: _controller.sent.length,
                  onChanged: _controller.showSide,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.visible.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    if (_controller.errorMessage != null && _controller.visible.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load offers',
        body: _controller.errorMessage!,
        action: TextButton(onPressed: _controller.load, child: const Text('Retry')),
      );
    }
    final userId = _controller.userId;
    if (_controller.visible.isEmpty || userId == null) {
      return _Message(
        icon: Icons.handshake_outlined,
        title: _controller.side == OffersSide.received ? 'No offers yet' : 'Nothing sent yet',
        body: _controller.side == OffersSide.received
            ? 'Offers buyers make on your listings will show up here.'
            : 'Open a listing and tap Make Offer to start a negotiation.',
      );
    }
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: _controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _controller.visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final offer = _controller.visible[index];
          return _OfferCard(
            offer: offer,
            userId: userId,
            busy: _controller.busyNegotiationId == offer.id,
            onAccept: () => _respond(offer, NegotiationAction.accept),
            onDecline: () => _respond(offer, NegotiationAction.decline),
            onCounter: () => _counter(offer),
          );
        },
      ),
    );
  }
}

class _SideToggle extends StatelessWidget {
  const _SideToggle({
    required this.side,
    required this.receivedCount,
    required this.sentCount,
    required this.onChanged,
  });

  final OffersSide side;
  final int receivedCount;
  final int sentCount;
  final ValueChanged<OffersSide> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(OffersSide value, String label, int count) {
      final selected = side == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$label ($count)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.gray,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          chip(OffersSide.received, 'Received', receivedCount),
          chip(OffersSide.sent, 'Sent', sentCount),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.userId,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  final NegotiationRecord offer;
  final int userId;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context) {
    final isBuyer = offer.isBuyer(userId);
    final myTurn = offer.isTurnOf(userId);
    final counterparty = offer.counterpartyName(userId);

    // Read the row from this user's side: "Maria offered…" vs "You offered…".
    final String headline;
    switch (offer.status) {
      case NegotiationStatus.pending:
        headline = isBuyer ? 'You offered' : '$counterparty offered';
      case NegotiationStatus.countered:
        headline = isBuyer ? '$counterparty countered with' : 'You countered with';
      case NegotiationStatus.accepted:
        headline = 'Agreed at';
      case NegotiationStatus.declined:
        headline = 'Declined at';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: myTurn ? AppColors.green : AppColors.border, width: myTurn ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  offer.cropName,
                  style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: offer.status, myTurn: myTurn),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isBuyer ? 'Seller: $counterparty' : 'Buyer: $counterparty',
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(headline, style: const TextStyle(color: AppColors.gray, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            'PHP ${formatAmount(offer.offeredPrice)} / ${offer.unit}  ×  ${formatAmount(offer.offeredQuantity)} ${offer.unit}',
            style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Text(
            'Total PHP ${formatAmount(offer.total)}  ·  asking PHP ${formatAmount(offer.basePrice)} / ${offer.unit}',
            style: const TextStyle(color: AppColors.gray, fontSize: 12),
          ),
          if (offer.status.isOpen) ...[
            const SizedBox(height: 14),
            _Actions(
              myTurn: myTurn,
              busy: busy,
              waitingOn: isBuyer ? 'seller' : 'buyer',
              onAccept: onAccept,
              onDecline: onDecline,
              onCounter: onCounter,
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.myTurn,
    required this.busy,
    required this.waitingOn,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  final bool myTurn;
  final bool busy;
  final String waitingOn;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 36,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green))),
      );
    }
    // The other side moved last: the only thing left to do is withdraw.
    if (!myTurn) {
      return Row(
        children: [
          Expanded(
            child: Text('Waiting for the $waitingOn…', style: const TextStyle(color: AppColors.gray, fontSize: 13)),
          ),
          TextButton(
            onPressed: onDecline,
            child: const Text('Withdraw', style: TextStyle(color: AppColors.gray)),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onDecline,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.black,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: onCounter,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green,
              side: const BorderSide(color: AppColors.green),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Counter'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept'),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.myTurn});

  final NegotiationStatus status;
  final bool myTurn;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      NegotiationStatus.pending || NegotiationStatus.countered when myTurn => ('Your turn', AppColors.green),
      NegotiationStatus.pending || NegotiationStatus.countered => ('Waiting', AppColors.gray),
      NegotiationStatus.accepted => ('Accepted', AppColors.greenLight),
      NegotiationStatus.declined => ('Declined', AppColors.gray),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.green),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.black, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray, fontSize: 14, height: 1.5)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
