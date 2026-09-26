import 'package:flutter/foundation.dart';

import '../../../shared/data/message_service.dart';
import '../../login/services/auth_service.dart';

/// Loads the signed-in user's inbox: one row per buyer/seller/listing thread.
class MessagesController extends ChangeNotifier {
  MessagesController({MessageService? service}) : _service = service ?? MessageService();

  final MessageService _service;

  List<ConversationRecord> conversations = const [];
  bool isLoading = false;
  String? errorMessage;

  int? get userId => AuthService.currentUserId;

  /// Threads with something the user has not seen yet.
  int get unreadThreadCount => conversations.where((c) => c.unreadCount > 0).length;

  Future<void> load() async {
    final id = userId;
    if (id == null) {
      errorMessage = 'Log in to see your messages.';
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      conversations = await _service.fetchConversations();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
