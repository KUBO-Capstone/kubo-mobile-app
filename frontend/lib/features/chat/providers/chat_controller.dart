import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/data/chat_socket.dart';
import '../../../shared/data/message_service.dart';
import '../../../shared/data/negotiation_service.dart';
import '../../login/services/auth_service.dart';

/// State for one conversation thread: the header (listing, parties, current
/// offer), the messages, and the offer actions.
///
/// New messages arrive over [ChatSocket]. Whenever the socket (re)connects,
/// the thread fetches only the messages after the newest one it has, so
/// nothing sent while the phone was offline goes missing.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.conversationId,
    MessageService? messages,
    NegotiationService? negotiations,
  })  : _messages = messages ?? MessageService(),
        _negotiations = negotiations ?? NegotiationService();

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

  StreamSubscription<MessageRecord>? _pushes;
  StreamSubscription<void>? _connects;
  String? _lastMessageId;
  bool _disposed = false;

  int? get userId => AuthService.currentUserId;

  /// The other person in the thread, from the signed-in user's side.
  String get counterpartyName {
    final id = userId;
    final thread = conversation;
    if (id == null || thread == null) return '';
    return thread.counterpartyName(id);
  }

  Future<void> start() async {
    // Subscribe before the first fetch so a push that lands mid-load is kept.
    _pushes ??= ChatSocket.messages
        .where((m) => m.conversationId == conversationId)
        .listen((m) => _receive([m]));
    _connects ??= ChatSocket.connects.listen((_) => _catchUp());
    await refresh();
  }

  /// Merges [incoming] into the thread by id. The sender gets the same
  /// message twice (REST response and socket echo), so ids are deduplicated.
  /// Returns the messages that were actually new.
  List<MessageRecord> _merge(Iterable<MessageRecord> incoming) {
    final known = {for (final m in messages) m.id};
    final fresh = incoming.where((m) => known.add(m.id)).toList();
    if (fresh.isEmpty) return fresh;
    messages = [...messages, ...fresh]..sort((a, b) => a.id.compareTo(b.id));
    _lastMessageId = messages.last.id;
    return fresh;
  }

  /// Applies pushed or caught-up messages: marks the other party's lines
  /// read, and reloads the header when an offer or order event moved the deal.
  Future<void> _receive(List<MessageRecord> incoming) async {
    final id = userId;
    if (_disposed || id == null) return;
    final fresh = _merge(incoming);
    if (fresh.isEmpty) return;
    notifyListeners();
    // The thread is on screen, so anything new from the other party is read.
    if (fresh.any((m) => !m.isMine(id))) {
      unawaited(_messages.markRead(conversationId: conversationId).catchError((_) {}));
    }
    if (fresh.any((m) => m.type != MessageType.text)) {
      try {
        conversation = await _messages.fetchConversation(conversationId: conversationId);
        if (!_disposed) notifyListeners();
      } catch (_) {
        // The header catches up on the next refresh.
      }
    }
  }

  /// Fetches whatever was sent while the socket was down.
  Future<void> _catchUp() async {
    final lastId = _lastMessageId;
    // Nothing loaded yet: the initial refresh() covers it.
    if (lastId == null) {
      if (conversation != null) await refresh(silent: true);
      return;
    }
    try {
      await _receive(await _messages.fetchMessages(conversationId: conversationId, afterId: lastId));
    } catch (_) {
      // Still offline; the next reconnect tries again.
    }
  }

  /// Reloads the header and messages. [silent] skips the loading flag so a
  /// background reload never flickers the screen.
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
        _messages.fetchConversation(conversationId: conversationId),
        _messages.fetchMessages(conversationId: conversationId),
      ]);
      if (_disposed) return;
      conversation = results[0] as ConversationRecord;
      // Merged, not replaced: a push may have landed while this was in flight.
      final fresh = _merge(results[1] as List<MessageRecord>);
      errorMessage = null;
      // Anything the other party sent is on screen now; clear the inbox dot.
      if (conversation!.isUnread || fresh.any((m) => !m.isMine(id))) {
        unawaited(_messages.markRead(conversationId: conversationId).catchError((_) {}));
      }
    } catch (error) {
      // A failed background reload keeps the last good thread on screen.
      if (!silent || conversation == null) {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      isLoading = false;
      if (!_disposed) notifyListeners();
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
        content: content,
      );
      // Sent over REST; the socket echo of the same id is ignored by _merge.
      _merge([sent]);
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
      final thread = conversation!;
      await _negotiations.createOffer(
        productId: thread.productId,
        price: price,
        quantity: quantity,
      );
    });
  }

  /// Accept, decline, or counter the current offer.
  Future<String?> respond(NegotiationAction action, {double? price, double? quantity}) {
    return _offerAction(() async {
      final negotiationId = conversation!.negotiationId!;
      await _negotiations.respond(
        negotiationId: negotiationId,
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
    _disposed = true;
    _pushes?.cancel();
    _connects?.cancel();
    _messages.dispose();
    _negotiations.dispose();
    super.dispose();
  }
}
