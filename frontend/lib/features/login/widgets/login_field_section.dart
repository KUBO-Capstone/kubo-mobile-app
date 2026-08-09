import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Reusable wrapper that gives each onboarding field a label, optional help text, and spacing.
class LoginFieldSection extends StatelessWidget {
  const LoginFieldSection({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.footerText,
  });

  /// Main label shown above the input control.
  final String label;

  /// Form control or custom widget rendered under the section label.
  final Widget child;

  /// Optional helper text used to explain the field before the input.
  final String? helperText;

  /// Optional footer text used for reassurance or field-specific notes.
  final String? footerText;

  @override
  // Lays out the label, optional guidance text, and the form control itself.
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