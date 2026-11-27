import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The full-width buttons at the bottom of the listing page.
///
/// A null [onPressed] disables the button (greyed out, no tap). [dimmed]
/// greys it out the same way but keeps it tappable: for an action that is
/// blocked for a reason the tap explains, such as an unfinished profile.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
    this.dimmed = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;
  final bool dimmed;

  static const _disabledColor = Color(0xFFD5D8D6);
  static const _disabledText = Color(0xFF6F7672);

  @override
  Widget build(BuildContext context) {
    final greyed = dimmed || onPressed == null;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: greyed ? _disabledColor : color,
          foregroundColor: greyed ? _disabledText : textColor,
          disabledBackgroundColor: _disabledColor,
          disabledForegroundColor: _disabledText,
          overlayColor: greyed ? AppColors.black : null,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
