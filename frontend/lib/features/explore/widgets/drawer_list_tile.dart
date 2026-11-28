// Helper widget for List titles in explore page, drawer
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';

class DrawerListTile extends StatelessWidget {
  final String title;

  /// SVG icon; [icon] is used instead when given.
  final String? iconPath;
  final IconData? icon;
  final int? tabIndex;

  /// Null shows the entry greyed out as "Coming soon" rather than as a
  /// button that does nothing.
  final VoidCallback? onTap;

  /// Green count at the end of the row, like the badges in the header; 0 hides it.
  final int badgeCount;

  /// Red, for Log Out.
  final bool destructive;

  const DrawerListTile({
    super.key,
    required this.title,
    this.iconPath,
    this.icon,
    this.tabIndex,
    this.onTap,
    this.badgeCount = 0,
    this.destructive = false,
  }) : assert(iconPath != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = !enabled ? AppColors.gray : destructive ? Colors.red.shade700 : Colors.black;
    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.only(left: 8, right: 8),
      leading: icon != null
          ? Icon(icon, size: 22, color: color)
          : AppSvgIcon(assetPath: iconPath!, size: 20, color: color),
      title: Text(title, style: destructive ? TextStyle(color: color, fontWeight: FontWeight.w600) : null),
      subtitle: enabled ? null : const Text('Coming Soon', style: TextStyle(fontSize: 12)),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(10)),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
