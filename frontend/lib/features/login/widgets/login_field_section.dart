import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class LoginFieldSection extends StatelessWidget {
  const LoginFieldSection({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.footerText,
  });

  final String label;
  final Widget child;
  final String? helperText;
  final String? footerText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 10),
        child,
        if (footerText != null) ...[
          const SizedBox(height: 6),
          Text(
            footerText!,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}