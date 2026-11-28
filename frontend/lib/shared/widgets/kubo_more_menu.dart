import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// One row of a [KuboMoreMenu].
class KuboMenuAction {
  const KuboMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// Drawn in red, for "Report".
  final bool isWarning;
}

/// The round kebab (⋮) button at the top right of the listing page and the
/// profile, opening a menu of [actions] (Share, Report) under it.
class KuboMoreMenu extends StatelessWidget {
  const KuboMoreMenu({
    super.key,
    required this.actions,
    this.background = AppColors.white,
    this.elevation = 2,
    this.tooltip = 'More options',
  });

  final List<KuboMenuAction> actions;

  /// The disc behind the icon; the listing page fades it out as its top bar
  /// turns solid.
  final Color background;
  final double elevation;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: elevation,
      shadowColor: Colors.black26,
      child: PopupMenuButton<int>(
        tooltip: tooltip,
        icon: const Icon(Icons.more_vert, color: AppColors.black),
        position: PopupMenuPosition.under,
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (index) => actions[index].onSelected(),
        itemBuilder: (_) => [
          for (final (index, action) in actions.indexed)
            PopupMenuItem<int>(
              value: index,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 20, color: action.isWarning ? Colors.redAccent : AppColors.black),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      action.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: action.isWarning ? Colors.redAccent : AppColors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
