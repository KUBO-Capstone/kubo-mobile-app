import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';
import '../../features/login/services/auth_service.dart';
import '../../features/shell/providers/app_shell_controller.dart';
import '../data/profile_service.dart';
import 'kubo_image.dart';

/// The app's bottom bar: Home, Search, the "+" create action, Market, Profile.
class KuboBottomNavigationBar extends StatelessWidget {
  /// The bar under the shell's tabs.
  const KuboBottomNavigationBar({
    super.key,
    required AppTab this.currentTab,
    required ValueChanged<AppTab> this.onTabSelected,
    required VoidCallback this.onCreatePressed,
  });

  /// The same bar on a page pushed above the shell, such as another user's
  /// profile or search results. It highlights the tab the user came from, and
  /// a tap goes back down to the shell first, so Profile always opens the
  /// signed-in user's own profile.
  const KuboBottomNavigationBar.detached({super.key})
      : currentTab = null,
        onTabSelected = null,
        onCreatePressed = null;

  final AppTab? currentTab;
  final ValueChanged<AppTab>? onTabSelected;
  final VoidCallback? onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final tab = currentTab;
    if (tab != null) {
      return _Bar(current: tab, onTabSelected: onTabSelected!, onCreatePressed: onCreatePressed!);
    }
    final shell = AppShellController.instance;
    return ListenableBuilder(
      listenable: shell,
      builder: (context, _) => _Bar(
        current: shell.current,
        onTabSelected: shell.goTo,
        onCreatePressed: () => shell.createListing(context),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.current, required this.onTabSelected, required this.onCreatePressed});

  final AppTab current;
  final ValueChanged<AppTab> onTabSelected;
  final VoidCallback onCreatePressed;

  void _select(AppTab tab) {
    HapticFeedback.selectionClick();
    onTabSelected(tab);
  }

  @override
  Widget build(BuildContext context) {
    // The bar has a fixed height; very large text would overflow it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: SafeArea(
        top: false,
        child: Container(
          height: 80,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavItem(
                label: 'Home',
                assetPath: AppIcons.home,
                isActive: current == AppTab.home,
                onTap: () => _select(AppTab.home),
              ),
              _NavItem(
                label: 'Search',
                assetPath: AppIcons.search,
                isActive: current == AppTab.search,
                onTap: () => _select(AppTab.search),
              ),
              _CenterAction(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCreatePressed();
                },
              ),
              _NavItem(
                label: 'Market',
                assetPath: AppIcons.chartLine,
                isActive: current == AppTab.market,
                onTap: () => _select(AppTab.market),
              ),
              _NavItem(
                label: 'Profile',
                assetPath: AppIcons.user,
                isActive: current == AppTab.profile,
                onTap: () => _select(AppTab.profile),
                icon: _ProfileTabIcon(isActive: current == AppTab.profile),
              ),
            ],
          ),
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
    this.icon,
  });

  final String label;
  final String assetPath;
  final bool isActive;
  final VoidCallback onTap;

  /// Replaces the SVG icon (the Profile tab shows the user's photo).
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.green : AppColors.gray;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon ?? AppSvgIcon(assetPath: assetPath, size: 22, color: color),
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
      ),
    );
  }
}

/// The signed-in user's photo in a ring, like the profile tab in most social
/// apps; the plain person icon until there is a photo.
class _ProfileTabIcon extends StatelessWidget {
  const _ProfileTabIcon({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: AuthService.currentUserListenable,
      builder: (context, user, _) {
        final photo = resolveProfilePhotoUrl(user?['profile_photo_url']?.toString());
        if (photo.isEmpty) {
          return AppSvgIcon(
            assetPath: AppIcons.user,
            size: 22,
            color: isActive ? AppColors.green : AppColors.gray,
          );
        }
        return Container(
          width: 24,
          height: 24,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.green : AppColors.border,
              width: isActive ? 2 : 1,
            ),
          ),
          child: ClipOval(child: KuboImage(photo, errorIcon: Icons.person)),
        );
      },
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
        child: Semantics(
          button: true,
          label: 'Create a listing',
          onTap: onTap,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: 30,
            child: const AppSvgIcon(
              assetPath: AppIcons.squarePlus,
              size: 28,
              color: AppColors.green,
            ),
          ),
        ),
      ),
    );
  }
}
