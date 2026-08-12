import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';

/// Single recent-search row with a history icon and remove action.
class SearchRecentSearchTile extends StatelessWidget {
  const SearchRecentSearchTile({
    super.key,
    required this.query,
    required this.onRemove,
  });

  /// Search term shown in the row.
  final String query;

  /// Removes the search term from the history list.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
      //   color: AppColors.softBackground,
      //   borderRadius: BorderRadius.circular(14),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const AppSvgIcon(
            assetPath: AppIcons.clock,
            size: 16,
            color: AppColors.gray,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkResponse(
            onTap: onRemove,
            radius: 16,
            child: const Icon(Icons.close, size: 18, color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}
