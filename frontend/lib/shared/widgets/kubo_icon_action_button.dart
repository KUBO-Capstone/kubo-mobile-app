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
  });

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

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size / 2 + 6,
      child: Container(
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
    );
  }
}
