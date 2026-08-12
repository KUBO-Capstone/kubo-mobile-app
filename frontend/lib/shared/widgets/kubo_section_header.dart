import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Reusable row header for sections that may expose a text action.
class KuboSectionHeader extends StatelessWidget {
  const KuboSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionPressed,
  });

  /// Main section title shown on the left side.
  final String title;

  /// Optional action label rendered on the trailing side.
  final String? actionLabel;

  /// Callback for the optional trailing action.
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onActionPressed != null;

    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (hasAction)
          TextButton(
            onPressed: onActionPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
