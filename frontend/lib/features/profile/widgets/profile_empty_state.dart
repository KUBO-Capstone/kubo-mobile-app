import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Empty state used when a profile section has no records yet.
class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  /// Title shown in the empty-state panel.
  final String title;

  /// Supporting message shown below the title.
  final String message;

  /// Optional action label shown below the message.
  final String? actionLabel;

  /// Optional callback for the action button.
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(24),
      // decoration: BoxDecoration(
      //   color: AppColors.softBackground,
      //   borderRadius: BorderRadius.circular(18),
      //   border: Border.all(color: AppColors.border),
      // ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: AppColors.green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onActionPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
