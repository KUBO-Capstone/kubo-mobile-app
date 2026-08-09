import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../widgets/explore_section_page.dart';

/// Bottom navigation strip that routes users to the main app sections.
class ExploreBottomNav extends StatelessWidget {
  const ExploreBottomNav({
    super.key,
    required this.currentIndex,
    required this.onIndexSelected,
  });

  /// Index of the currently active tab.
  final int currentIndex;

  /// Callback used when the user changes the selected tab.
  final ValueChanged<int> onIndexSelected;

  @override
  // Builds the bottom nav row and the central create-listing action.
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavItem(
            label: 'Home',
            assetPath: AppIcons.home,
            isActive: currentIndex == 0,
            onTap: () => onIndexSelected(0),
          ),
          _NavItem(
            label: 'Search',
            assetPath: AppIcons.search,
            isActive: currentIndex == 1,
            onTap: () => _openSection(
              context,
              'Search',
              'Search tools and filters will be added here next.',
            ),
          ),
          _CenterAction(
            onTap: () => _openSection(
              context,
              'Create Listing',
              'The listing creation flow will live here.',
            ),
          ),
          _NavItem(
            label: 'Market',
            assetPath: AppIcons.chartLine,
            isActive: currentIndex == 3,
            onTap: () => _openSection(
              context,
              'Insights',
              'Performance and activity insights will appear here.',
            ),
          ),
          _NavItem(
            label: 'Profile',
            assetPath: AppIcons.user,
            isActive: currentIndex == 4,
            onTap: () => _openSection(
              context,
              'Profile',
              'Profile settings and account details will appear here.',
            ),
          ),
        ],
      ),
    );
  }

  // Opens one of the placeholder destination pages from the bottom nav.
  void _openSection(BuildContext context, String title, String message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreSectionPage(title: title, message: message),
      ),
    );
  }
}

/// Individual bottom-nav item that highlights the active section.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.assetPath,
    required this.isActive,
    required this.onTap,
  });

  /// Text label shown under the icon.
  final String label;

  /// SVG asset used for the nav item icon.
  final String assetPath;

  /// Whether this item should render with the active accent color and dot.
  final bool isActive;

  /// Tap handler used to activate the item.
  final VoidCallback onTap;

  @override
  // Renders the icon, label, and active-dot indicator for one nav item.
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

/// Center action button used for the create-listing shortcut.
class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.onTap});

  /// Tap handler for the central create-listing action.
  final VoidCallback onTap;

  @override
  // Centers the plus icon above the bottom nav bar so it reads as a primary action.
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