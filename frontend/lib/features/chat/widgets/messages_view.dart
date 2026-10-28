import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/message_service.dart';
import '../providers/messages_controller.dart';
import '../screens/chat_page.dart';

/// Inbox body: one row per thread, newest activity first, with the last
/// message as the preview and a green dot while something is unread.
/// Body of [MessagesPage], which is reached from the chat icon in the
/// explore app bar.
class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  late final MessagesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MessagesController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(ConversationRecord thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatPage(conversationId: thread.id)),
    );
    // Whatever happened in the thread (read, replied, offered) changes the row.
    if (mounted) _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final userId = _controller.userId;
        if (_controller.isLoading && _controller.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.green));
        }
        final error = _controller.errorMessage;
        if (error != null) {
          return _Empty(message: error, onRetry: _controller.load);
        }
        if (_controller.conversations.isEmpty || userId == null) {
          return _Empty(
            message: 'No conversations yet. Make an offer or message a seller from a listing to start one.',
            onRetry: _controller.load,
          );
        }
        return RefreshIndicator(
          color: AppColors.green,
          onRefresh: _controller.load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _controller.conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, index) {
              final thread = _controller.conversations[index];
              return _ConversationTile(
                thread: thread,
                userId: userId,
                onTap: () => _open(thread),
              );
            },
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.thread, required this.userId, required this.onTap});

  final ConversationRecord thread;
  final int userId;
  final VoidCallback onTap;

  /// "Display name: last message", with offer events summarised so the
  /// inbox reads like Carousell's rather than showing raw text.
  String get _preview {
    final last = thread.lastMessage;
    if (last == null) return thread.cropName;
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final unread = thread.isUnread;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.black,
        child: Icon(Icons.person, size: 20, color: AppColors.white),
      ),
      title: Text(
        thread.counterpartyName(userId),
        style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '${thread.cropName} · $_preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread ? AppColors.black : AppColors.gray,
            fontSize: 12,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      trailing: unread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.green),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
