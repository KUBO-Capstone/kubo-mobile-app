import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';

/// Shared bottom navigation used by the home, search, market, and profile tabs.
class KuboBottomNavigationBar extends StatelessWidget {
  const KuboBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.onCenterActionPressed,
  });

  /// Currently active tab index.
  final int currentIndex;

  /// Callback invoked when the user selects a destination tab.
  final ValueChanged<int> onDestinationSelected;

  /// Optional callback for the center create-listing action.
  final VoidCallback? onCenterActionPressed;

  static const List<_BottomNavItemData> _items = <_BottomNavItemData>[
    _BottomNavItemData(label: 'Home', assetPath: AppIcons.home),
    _BottomNavItemData(label: 'Search', assetPath: AppIcons.search),
    _BottomNavItemData(
      label: 'Add',
      assetPath: AppIcons.squarePlus,
      isPrimaryAction: true,
    ),
    _BottomNavItemData(label: 'Market', assetPath: AppIcons.chartLine),
    _BottomNavItemData(label: 'Profile', assetPath: AppIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 80,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: List<Widget>.generate(_items.length, (index) {
            final item = _items[index];
            if (item.isPrimaryAction) {
              return _CenterAction(
                onTap:
                    onCenterActionPressed ?? () => onDestinationSelected(index),
              );
            }

            final adjustedIndex = index < 2 ? index : index - 1;
            return _NavItem(
              label: item.label,
              assetPath: item.assetPath,
              isActive: currentIndex == adjustedIndex,
              onTap: () => onDestinationSelected(adjustedIndex),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.assetPath,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.green : AppColors.gray;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSvgIcon(assetPath: assetPath, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.green : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: InkResponse(
          onTap: onTap,
          radius: 30,
          child: AppSvgIcon(
            assetPath: AppIcons.squarePlus,
            size: 28,
            color: AppColors.green,
          ),
        ),
      ),
    );
  }
}

class _BottomNavItemData {
  const _BottomNavItemData({
    required this.label,
    required this.assetPath,
    this.isPrimaryAction = false,
  });

  final String label;
  final String assetPath;
  final bool isPrimaryAction;
}
