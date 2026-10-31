import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/data/message_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../../shared/data/order_service.dart';
import '../../../shared/data/review_service.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../../shared/widgets/kubo_star_rating.dart';
import '../../deals/screens/deal_celebration_page.dart';
import '../../earnings/screens/lifetime_earnings_page.dart';
import '../../listing/screens/listing_page.dart';
import '../../reviews/screens/write_review_page.dart';
import '../../listing/widgets/make_offer_dialog.dart';
import '../../orders/screens/order_page.dart';
import '../../orders/screens/place_order_page.dart';
import '../../profile/screens/profile_page.dart';
import '../providers/chat_controller.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_product_header.dart';

/// One buyer/seller thread about a listing. The listing card at the top
/// carries the offer controls; offers, counters and accept/decline show up
/// in the thread as messages, Carousell-style.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversationId});

  static const routeName = '/chat';

  final int conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatController _controller;
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  int _renderedCount = 0;

  // Negotiations already celebrated on this screen, so a refresh that lands
  // before the server records it does not open the page twice.
  final Set<int> _celebrated = <int>{};

  @override
  void initState() {
    super.initState();
    _controller = ChatController(conversationId: widget.conversationId);
    _controller.addListener(_scrollToEndOnNewMessages);
    _controller.addListener(_celebrateClosedDeal);
    _controller.start();
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollToEndOnNewMessages);
    _controller.removeListener(_celebrateClosedDeal);
    _controller.dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Keeps the newest message in view whenever the list grows.
  void _scrollToEndOnNewMessages() {
    final count = _controller.messages.length;
    if (count == _renderedCount) return;
    _renderedCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  // Opens the "deal closed" screen the first time this person sees an
  // accepted offer: right after accepting, when the other side's accept
  // arrives over the socket, or on opening the thread later.
  void _celebrateClosedDeal() {
    final thread = _controller.conversation;
    final userId = _controller.userId;
    final negotiationId = thread?.negotiationId;
    if (thread == null || userId == null || negotiationId == null || !thread.celebrationPending) return;
    if (_celebrated.contains(negotiationId)) return;
    // Wait until the chat is on top again rather than covering another page.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _celebrated.add(negotiationId);
    _controller.markCelebrated(negotiationId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final action = await Navigator.of(context).push<DealCelebrationAction>(
        MaterialPageRoute<DealCelebrationAction>(
          fullscreenDialog: true,
          builder: (_) => DealCelebrationPage(
            isSeller: thread.isSeller(userId),
            acceptedByMe: thread.acceptedBy == userId,
            counterpartyName: thread.counterpartyName(userId),
            cropName: thread.cropName,
            quantity: thread.offeredQuantity ?? 0,
            unit: thread.unit,
            price: thread.offeredPrice ?? 0,
          ),
        ),
      );
      if (!mounted) return;
      final latest = _controller.conversation ?? thread;
      switch (action) {
        case DealCelebrationAction.arrangePickup:
          if (latest.canPlaceOrder(userId)) await _placeOrder(latest);
        case DealCelebrationAction.viewEarnings:
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LifetimeEarningsPage()));
        case null:
          break;
      }
    });
  }

  // Either side rates the other once the order is delivered.
  Future<void> _rateOrder(int orderId) async {
    final service = OrderService();
    try {
      final order = await service.fetchOrder(orderId: orderId);
      if (!mounted) return;
      final review = await Navigator.of(context).push<ReviewRecord>(
        MaterialPageRoute<ReviewRecord>(builder: (_) => WriteReviewPage(order: order)),
      );
      if (review != null && mounted) await _controller.refresh(silent: true);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      service.dispose();
    }
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    _composer.clear();
    final error = await _controller.send(text);
    if (error != null) {
      // Put the text back so a failed send is not lost.
      _composer.text = text;
      _showError(error);
    }
  }

  // The offer dialog wants a listing record; build one from the thread.
  SyntheticListingRecord _listingFor(ConversationRecord thread) {
    return SyntheticListingRecord(
      id: '${thread.productId}',
      title: thread.cropName,
      price: 'PHP ${thread.basePrice}',
      locationLabel: thread.sellerLocation,
      regionLabel: '',
      sellerLabel: thread.sellerName,
      imageAssetPath: thread.productImage ?? 'assets/images/Placeholder_img.png',
      productId: thread.productId,
      sellerId: thread.sellerId,
      basePrice: thread.basePrice,
      unit: thread.unit,
      status: thread.productStatus,
    );
  }

  Future<void> _makeOffer(ConversationRecord thread) async {
    final offer = await showMakeOfferDialog(context, _listingFor(thread));
    if (offer == null) return;
    // The dialog already posted the offer; the thread just needs re-reading.
    await _controller.refresh(silent: true);
  }

  Future<void> _respond(NegotiationAction action, {double? price, double? quantity}) async {
    _showError(await _controller.respond(action, price: price, quantity: quantity));
  }

  // Buyer turns the accepted offer into an order; the server writes the
  // "Placed order" line, so the thread only needs re-reading afterwards.
  Future<void> _placeOrder(ConversationRecord thread) async {
    final offer = thread.negotiation;
    if (offer == null) return;
    final order = await Navigator.of(context).push<OrderRecord>(
      MaterialPageRoute<OrderRecord>(builder: (_) => PlaceOrderPage(offer: offer)),
    );
    if (order == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${order.id} placed.')),
    );
    await _controller.refresh(silent: true);
  }

  Future<void> _openOrder(int orderId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => OrderPage(orderId: orderId, openChat: false)),
    );
    if (mounted) await _controller.refresh(silent: true);
  }

  Future<void> _openListing(ConversationRecord thread) async {
    final service = ListingService();
    try {
      final listing = await service.fetchListing(thread.productId);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ListingPage(listing: listing)));
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      service.dispose();
    }
  }

  void _openCounterpartyProfile(ConversationRecord thread, int userId) {
    final otherId = thread.isBuyer(userId) ? thread.sellerId : thread.buyerId;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage.forSeller(
          sellerId: otherId,
          sellerName: thread.counterpartyName(userId),
          locationLabel: thread.isBuyer(userId) ? thread.sellerLocation : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final thread = _controller.conversation;
        final userId = _controller.userId;

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              _controller.counterpartyName,
              style: const TextStyle(color: AppColors.black, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              if (thread != null && userId != null) ...[
                ChatProductHeader(
                  conversation: thread,
                  userId: userId,
                  busy: _controller.isOfferBusy,
                  onMakeOffer: () => _makeOffer(thread),
                  onRespond: _respond,
                  onPlaceOrder: () => _placeOrder(thread),
                  onOpenOrder: _openOrder,
                  onRateOrder: _rateOrder,
                  onOpenListing: () => _openListing(thread),
                ),
                _CounterpartyBlock(
                  name: thread.counterpartyName(userId),
                  location: thread.isBuyer(userId) ? thread.sellerLocation : null,
                  rating: thread.counterpartyRating(userId),
                  reviewCount: thread.counterpartyReviewCount(userId),
                  onTap: () => _openCounterpartyProfile(thread, userId),
                ),
              ],
              Expanded(child: _buildThread(userId)),
            ],
          ),
          bottomNavigationBar: ChatInputBar(
            controller: _composer,
            onSend: _send,
            sending: _controller.isSending,
          ),
        );
      },
    );
  }

  Widget _buildThread(int? userId) {
    if (_controller.isLoading && _controller.conversation == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.green));
    }
    final error = _controller.errorMessage;
    if (error != null && _controller.conversation == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gray)),
              const SizedBox(height: 12),
              TextButton(onPressed: _controller.refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final messages = _controller.messages;
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No messages yet. Say hello or make an offer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final message = messages[index];
        return ChatMessageBubble(
          message: message,
          isMine: userId != null && message.isMine(userId),
          onOpenOrder: _openOrder,
        );
      },
    );
  }
}

/// The avatar / name / location / rating block under the listing card.
class _CounterpartyBlock extends StatelessWidget {
  const _CounterpartyBlock({
    required this.name,
    required this.onTap,
    required this.rating,
    required this.reviewCount,
    this.location,
  });

  final String name;
  final String? location;
  final double? rating;
  final int reviewCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.black,
              child: Icon(Icons.person, size: 26, color: AppColors.white),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            if (location != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.gray),
                  const SizedBox(width: 2),
                  Text(location!, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            KuboRatingLine(average: rating, count: reviewCount, fontSize: 11),
          ],
        ),
      ),
    );
  }
}
