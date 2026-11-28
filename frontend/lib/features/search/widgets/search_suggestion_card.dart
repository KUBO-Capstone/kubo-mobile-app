import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/listing_service.dart';
import '../../../shared/widgets/kubo_image.dart';

/// Grid card for one popular search: the cover photo of a listing that
/// matches it, and the words it searches for.
class SearchSuggestionCard extends StatelessWidget {
  const SearchSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  /// Data used to render the suggestion tile.
  final ListingSuggestion suggestion;

  /// Opens the search results page for the selected suggestion.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = suggestion.imageUrl;
    final count = suggestion.listingCount;

    return Semantics(
      button: true,
      label: 'Search for ${suggestion.text}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Takes whatever the label leaves, so a large text size never
              // overflows the card.
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  child: image == null
                      ? const ColoredBox(
                          color: AppColors.softBackground,
                          child: Center(
                            child: Icon(Icons.eco_outlined, size: 36, color: AppColors.gray),
                          ),
                        )
                      : KuboImage(image),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  children: [
                    Text(
                      suggestion.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$count listing${count == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.gray, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
