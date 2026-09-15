import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/data/message_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../login/services/auth_service.dart';

/// State for one conversation thread: the header (listing, parties, current
/// offer), the messages, and the offer actions.
///
/// There are no sockets, so the thread re-fetches every [pollInterval] while
/// the screen is open. That is plenty for a two-person demo.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.conversationId,
    MessageService? messages,
    NegotiationService? negotiations,
  })  : _messages = messages ?? MessageService(),
        _negotiations = negotiations ?? NegotiationService();

  static const pollInterval = Duration(seconds: 4);

  final int conversationId;
  final MessageService _messages;
  final NegotiationService _negotiations;

  ConversationRecord? conversation;
  List<MessageRecord> messages = const [];
  bool isLoading = true;
  bool isSending = false;

  /// True while an accept / decline / counter request is in flight.
  bool isOfferBusy = false;
  String? errorMessage;

  Timer? _poll;
  int? _lastMessageId;

  int? get userId => AuthService.currentUserId;

  /// The other person in the thread, from the signed-in user's side.
  String get counterpartyName {
    final id = userId;
    final thread = conversation;
    if (id == null || thread == null) return '';
    return thread.counterpartyName(id);
  }

  Future<void> start() async {
    await refresh();
    _poll ??= Timer.periodic(pollInterval, (_) => refresh(silent: true));
  }

  /// Reloads the header and messages. [silent] skips the loading flag so a
  /// background poll never flickers the screen.
  Future<void> refresh({bool silent = false}) async {
    final id = userId;
    if (id == null) {
      errorMessage = 'Log in to view messages.';
      isLoading = false;
      notifyListeners();
      return;
    }
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final results = await Future.wait<Object>([
        _messages.fetchConversation(conversationId: conversationId, userId: id),
        _messages.fetchMessages(conversationId: conversationId, userId: id),
      ]);
      conversation = results[0] as ConversationRecord;
      final fetched = results[1] as List<MessageRecord>;
      final newest = fetched.isEmpty ? null : fetched.last.id;
      final hasNew = newest != _lastMessageId;
      messages = fetched;
      _lastMessageId = newest;
      errorMessage = null;
      // Anything the other party sent is on screen now; clear the inbox dot.
      if (hasNew && fetched.any((m) => !m.isMine(id) && m.readAt == null)) {
        unawaited(_messages.markRead(conversationId: conversationId, userId: id));
      }
    } catch (error) {
      // A failed background poll keeps the last good thread on screen.
      if (!silent || conversation == null) {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a typed message. Returns an error string to show, or null.
  Future<String?> send(String text) async {
    final id = userId;
    final content = text.trim();
    if (id == null) return 'Log in to send messages.';
    if (content.isEmpty) return null;
    isSending = true;
    notifyListeners();
    try {
      final sent = await _messages.sendMessage(
        conversationId: conversationId,
        senderId: id,
        content: content,
      );
      messages = [...messages, sent];
      _lastMessageId = sent.id;
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  /// Buyer opens a new offer on the thread's listing.
  Future<String?> makeOffer({required double price, required double quantity}) {
    return _offerAction(() async {
      final id = userId!;
      final thread = conversation!;
      await _negotiations.createOffer(
        buyerId: id,
        productId: thread.productId,
        price: price,
        quantity: quantity,
      );
    });
  }

  /// Accept, decline, or counter the current offer.
  Future<String?> respond(NegotiationAction action, {double? price, double? quantity}) {
    return _offerAction(() async {
      final id = userId!;
      final negotiationId = conversation!.negotiationId!;
      await _negotiations.respond(
        negotiationId: negotiationId,
        userId: id,
        action: action,
        price: price,
        quantity: quantity,
      );
    });
  }

  // Every offer step writes a message server-side, so after the call the
  // thread is simply re-fetched rather than patched locally.
  Future<String?> _offerAction(Future<void> Function() call) async {
    if (userId == null || conversation == null) return 'Log in to make offers.';
    isOfferBusy = true;
    notifyListeners();
    try {
      await call();
      await refresh(silent: true);
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Exception: ', '');
    } finally {
      isOfferBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _messages.dispose();
    _negotiations.dispose();
    super.dispose();
  }
}
