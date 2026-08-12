import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';

/// Shared search field used by Search and Search Results pages.
class KuboSearchField extends StatelessWidget {
  const KuboSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hintText = 'Search',
    this.onClear,
    this.autofocus = false,
  });

  /// Controller that stores the current query text.
  final TextEditingController controller;

  /// Called when the user submits the search term.
  final ValueChanged<String> onSubmitted;

  /// Hint text displayed when the field is empty.
  final String hintText;

  /// Optional callback used for the clear icon.
  final VoidCallback? onClear;

  /// Whether the field should autofocus when the screen opens.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const AppSvgIcon(
            assetPath: AppIcons.search,
            size: 20,
            color: AppColors.gray,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }

              return InkResponse(
                onTap: onClear,
                radius: 16,
                child: const Icon(Icons.close, size: 18, color: AppColors.gray),
              );
            },
          ),
        ],
      ),
    );
  }
}
