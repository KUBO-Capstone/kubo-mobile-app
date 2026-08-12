import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/search_page_controller.dart';

/// Grid card that shows one image and label for a search suggestion.
class SearchSuggestionCard extends StatelessWidget {
  const SearchSuggestionCard({super.key, required this.suggestion});

  /// Data used to render the suggestion tile.
  final SearchSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(suggestion.imageAssetPath, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
            child: Text(
              suggestion.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
