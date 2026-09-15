import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Composer pinned to the bottom of the chat: image button, text field, send.
/// The image button is a placeholder until uploads exist.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// Disables the send button while a message is in flight.
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Attach a photo (coming soon)',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo messages are not available yet.')),
              ),
              icon: const Icon(Icons.image_outlined, color: AppColors.gray),
            ),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.softBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                    hintStyle: TextStyle(color: AppColors.gray, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(color: AppColors.black, fontSize: 13),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final canSend = !sending && value.text.trim().isNotEmpty;
                return IconButton(
                  onPressed: canSend ? onSend : null,
                  icon: Icon(
                    Icons.send_outlined,
                    color: canSend ? AppColors.green : AppColors.gray,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
