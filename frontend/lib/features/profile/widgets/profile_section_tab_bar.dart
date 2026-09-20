import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/profile_page_controller.dart';

/// Tab row used to switch between the profile sections.
class ProfileSectionTabBar extends StatelessWidget {
  const ProfileSectionTabBar({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
    this.showSavedTab = true,
    this.showOrdersTab = true,
  });

  /// Currently selected section.
  final ProfileSection selectedSection;

  /// Callback invoked when a section tab is tapped.
  final ValueChanged<ProfileSection> onSectionSelected;

  /// Whether the Saved tab should be shown.
  final bool showSavedTab;

  /// Whether the Orders tab should be shown (own profile only).
  final bool showOrdersTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          _ProfileTabButton(
            label: 'Listings',
            selected: selectedSection == ProfileSection.listings,
            onTap: () => onSectionSelected(ProfileSection.listings),
          ),
          _ProfileTabButton(
            label: 'Reviews',
            selected: selectedSection == ProfileSection.reviews,
            onTap: () => onSectionSelected(ProfileSection.reviews),
          ),
          _ProfileTabButton(
            label: 'About',
            selected: selectedSection == ProfileSection.about,
            onTap: () => onSectionSelected(ProfileSection.about),
          ),
          if (showSavedTab)
            _ProfileTabButton(
              label: 'Saved',
              selected: selectedSection == ProfileSection.saved,
              onTap: () => onSectionSelected(ProfileSection.saved),
            ),
          if (showOrdersTab)
            _ProfileTabButton(
              label: 'Orders',
              selected: selectedSection == ProfileSection.orders,
              onTap: () => onSectionSelected(ProfileSection.orders),
            ),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.gray;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(
                color: selected ? AppColors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
