import 'package:flutter/material.dart';

//import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';

/// Shared list/map view toggle used by explore and search result screens.
class KuboViewToggleButton extends StatelessWidget {
  const KuboViewToggleButton({
    super.key,
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// SVG icon shown before the label.
  final String assetPath;

  /// Button label.
  final String label;

  /// Whether the toggle is active.
  final bool selected;

  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.gray;

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(assetPath: assetPath, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            width: 62,
            height: 2,
            color: selected ? AppColors.green : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
