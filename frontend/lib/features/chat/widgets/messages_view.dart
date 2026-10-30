import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/message_service.dart';
import '../../../shared/widgets/kubo_image.dart';
import '../../../shared/widgets/kubo_skeleton.dart';
import '../providers/messages_controller.dart';
import '../screens/chat_page.dart';

/// Inbox body: one row per thread, newest activity first, with the listing's
/// photo, the last message as the preview, when it was sent, and a green dot
/// while something is unread. Body of [MessagesPage], which is reached from
/// the chat icon in the explore app bar.
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
    if (mounted) _controller.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final userId = _controller.userId;
        if (_controller.isLoading && _controller.conversations.isEmpty) {
          return const SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            child: ListRowsSkeleton(thumbnailSize: 52),
          );
        }
        final error = _controller.errorMessage;
        if (error != null && _controller.conversations.isEmpty) {
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
          onRefresh: () => _controller.load(silent: true),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _controller.conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 80, color: AppColors.border),
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

/// "now", "5m", "3h" today; "Mon" within the week; "Mar 2" this year;
/// "3/2/25" before that. The short form messaging apps use in an inbox.
String inboxTimeLabel(DateTime? sentAt, {DateTime? now}) {
  if (sentAt == null) return '';
  final local = sentAt.toLocal();
  final current = now ?? DateTime.now();
  final difference = current.difference(local);
  if (difference.inMinutes < 1) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  final sameDay = local.year == current.year && local.month == current.month && local.day == current.day;
  if (sameDay) return '${difference.inHours}h';
  if (difference.inDays < 7) {
    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[local.weekday - 1];
  }
  const months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (local.year == current.year) return '${months[local.month - 1]} ${local.day}';
  return '${local.month}/${local.day}/${local.year % 100}';
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
    final image = thread.productImage;
    final time = inboxTimeLabel(thread.lastMessageAt);
    final name = thread.counterpartyName(userId);

    return Semantics(
      label: unread ? 'Unread conversation with $name' : 'Conversation with $name',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // The listing's photo says which deal the thread is about at a
              // glance, the way Carousell's inbox does.
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: image == null
                    ? Container(
                        width: 52,
                        height: 52,
                        color: AppColors.softBackground,
                        child: const Icon(Icons.storefront_outlined, color: AppColors.gray),
                      )
                    : KuboImage(image, width: 52, height: 52, errorIcon: Icons.storefront_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              color: unread ? AppColors.green : AppColors.gray,
                              fontSize: 11,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
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
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
