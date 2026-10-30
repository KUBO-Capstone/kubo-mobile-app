import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/data/chat_socket.dart';
import '../../../shared/data/message_service.dart';
import '../../login/services/auth_service.dart';

/// Loads the signed-in user's inbox: one row per buyer/seller/listing thread.
///
/// Reloads quietly whenever [ChatSocket] pushes a message (previews, order
/// and unread counts all live server-side) and after every reconnect.
class MessagesController extends ChangeNotifier {
  MessagesController({MessageService? service}) : _service = service ?? MessageService() {
    _pushes = ChatSocket.messages.listen((_) => load(silent: true));
    _connects = ChatSocket.connects.listen((_) => load(silent: true));
  }

  final MessageService _service;
  late final StreamSubscription<MessageRecord> _pushes;
  late final StreamSubscription<void> _connects;
  bool _disposed = false;

  List<ConversationRecord> conversations = const [];
  bool isLoading = false;
  String? errorMessage;

  int? get userId => AuthService.currentUserId;

  /// Threads with something the user has not seen yet.
  int get unreadThreadCount => conversations.where((c) => c.isUnread).length;

  /// [silent] skips the loading flag and keeps the last good inbox on a
  /// failed background reload.
  Future<void> load({bool silent = false}) async {
    final id = userId;
    if (id == null) {
      if (silent) return;
      errorMessage = 'Log in to see your messages.';
      notifyListeners();
      return;
    }
    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      conversations = await _service.fetchConversations();
      errorMessage = null;
    } catch (error) {
      if (!silent) errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pushes.cancel();
    _connects.cancel();
    _service.dispose();
    super.dispose();
  }
}
