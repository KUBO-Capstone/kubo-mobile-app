import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Composer pinned to the bottom of the chat: photo button, text field, send.
/// The field grows with what is typed, up to five lines, then scrolls.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.sending,
    this.onAttachPhoto,
    this.sendingPhoto = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  /// Disables the send button while a message is in flight.
  final bool sending;

  /// Picks and sends a photo; null hides the button.
  final VoidCallback? onAttachPhoto;

  /// A photo is uploading: the photo button shows progress instead.
  final bool sendingPhoto;

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
          // The buttons stay level with the last line as the field grows.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onAttachPhoto != null)
              sendingPhoto
                  ? const SizedBox(
                      width: 48,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Send a photo',
                      onPressed: onAttachPhoto,
                      icon: const Icon(Icons.image_outlined, color: AppColors.green),
                    ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.softBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                // No `alignment` here: an aligned Container grows to all the
                // height it is offered, which under bottomNavigationBar is the
                // whole screen. The box is as tall as the text, 1 to 5 lines.
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  // Enter starts a new line; the send button sends.
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Write a message',
                    hintStyle: TextStyle(color: AppColors.gray, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(color: AppColors.black, fontSize: 13, height: 1.35),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final canSend = !sending && value.text.trim().isNotEmpty;
                return IconButton(
                  tooltip: 'Send',
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
