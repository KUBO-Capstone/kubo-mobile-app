import 'package:flutter/material.dart';

import '../../../shared/data/synthetic_records.dart';
import '../../../core/constants/app_colors.dart';

/// Grid card that shows one image and label for a search suggestion.
class SearchSuggestionCard extends StatelessWidget {
  const SearchSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  /// Data used to render the suggestion tile.
  final SyntheticSearchSuggestion suggestion;

  /// Opens the search results page for the selected suggestion.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  suggestion.imageAssetPath,
                  fit: BoxFit.cover,
                ),
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
      ),
    );
  }
}
