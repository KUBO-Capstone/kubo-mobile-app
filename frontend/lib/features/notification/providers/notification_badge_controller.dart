import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/data/chat_socket.dart';
import '../../login/services/auth_service.dart';
import 'notification_provider.dart';

/// The unread count on the bell icon. One for the whole app, so the explore
/// header, the menu and the notifications page agree. Recounts when the
/// server pushes `notification:new`, after every reconnect, and whenever a
/// screen asks ([refresh]).
class NotificationBadgeController extends ChangeNotifier {
  NotificationBadgeController._() {
    _pushes = ChatSocket.notifications.listen((_) => refresh());
    _connects = ChatSocket.connects.listen((_) => refresh());
  }

  static final NotificationBadgeController instance = NotificationBadgeController._();

  late final StreamSubscription<void> _pushes;
  late final StreamSubscription<void> _connects;

  int unreadCount = 0;
  int _request = 0;

  /// Asks the server for the count. A failure keeps the last one shown.
  Future<void> refresh() async {
    if (AuthService.currentUserId == null) {
      setCount(0);
      return;
    }
    final request = ++_request;
    final provider = NotificationProvider();
    try {
      final count = await provider.fetchUnreadCount();
      // An older answer arriving after a newer one is dropped.
      if (request == _request) setCount(count);
    } catch (_) {
      // Offline: the badge catches up on the next reconnect.
    } finally {
      provider.dispose();
    }
  }

  /// Sets the count from what a screen already knows (one opened, all read).
  void setCount(int count) {
    final value = count < 0 ? 0 : count;
    if (value == unreadCount) return;
    unreadCount = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _pushes.cancel();
    _connects.cancel();
    super.dispose();
  }
}
