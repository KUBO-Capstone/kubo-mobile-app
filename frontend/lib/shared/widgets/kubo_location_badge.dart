import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';

/// Compact green location label shared by explore and search result screens.
class KuboLocationBadge extends StatelessWidget {
  const KuboLocationBadge({super.key, required this.label});

  static const maxLabelLength = 20;

  /// Location text rendered next to the pin icon.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppSvgIcon(
          assetPath: AppIcons.locationDot,
          size: 16,
          color: AppColors.green,
        ),
        const SizedBox(width: 4),
        Text(
          _displayLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.green,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String get _displayLabel {
    if (label.length <= maxLabelLength) {
      return label;
    }
    return '${label.substring(0, maxLabelLength - 3)}...';
  }
}
