// Helper widget for List titles in explore page, drawer
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';

class DrawerListTile extends StatelessWidget {
  final String title;
  final String iconPath;
  final int? tabIndex;

  /// Null shows the entry greyed out as "Coming soon" rather than as a
  /// button that does nothing.
  final VoidCallback? onTap;

  const DrawerListTile({
    super.key,
    required this.title,
    required this.iconPath,
    this.tabIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.only(left: 8),
      leading: AppSvgIcon(
        assetPath: iconPath,
        size: 20,
        color: enabled ? Colors.black : AppColors.gray,
      ),
      title: Text(title),
      subtitle: enabled ? null : const Text('Coming soon', style: TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
