import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';

/// Circular SVG icon button used for compact app-bar actions.
class KuboIconActionButton extends StatelessWidget {
  const KuboIconActionButton({
    super.key,
    required this.assetPath,
    required this.onTap,
    this.size = 32,
    this.iconSize = 20,
    this.backgroundColor = AppColors.white,
    this.iconColor = AppColors.black,
    this.badgeCount = 0,
    this.tooltip,
  });

  /// Shown on long press and read out by screen readers.
  final String? tooltip;

  /// SVG icon asset rendered inside the button.
  final String assetPath;

  /// Callback triggered when the button is tapped.
  final VoidCallback onTap;

  /// Diameter of the circular container.
  final double size;

  /// Size of the SVG icon inside the container.
  final double iconSize;

  /// Fill color for the button background.
  final Color backgroundColor;

  /// Tint color applied to the icon.
  final Color iconColor;

  /// Count shown in a green badge on the top-right corner (same green as the
  /// inbox unread dot); 0 hides the badge.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final label = tooltip;
    final button = InkResponse(
      onTap: onTap,
      radius: size / 2 + 6,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppSvgIcon(
                  assetPath: assetPath,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: backgroundColor, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (label == null) return button;
    final unread = badgeCount > 0 ? ', $badgeCount unread' : '';
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: '$label$unread',
        onTap: onTap,
        excludeSemantics: true,
        child: button,
      ),
    );
  }
}
