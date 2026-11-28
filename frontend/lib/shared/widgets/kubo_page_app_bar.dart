import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The flat white top bar of a full page (Notifications, Market, Saved,
/// Account Settings): the title in small spaced capitals, centred, with a
/// back chevron when the page can be left.
class KuboPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const KuboPageAppBar({super.key, required this.title, this.actions});

  /// Shown in capitals whatever case it is given in.
  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.black),
              // maybePop, so a page that guards unsaved changes still asks.
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      actions: actions,
    );
  }
}
