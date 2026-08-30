import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_svg_icon.dart';
import '../../features/listing/screens/listing_page.dart';
import '../data/synthetic_records.dart';

/// Shared listing card used across explore and search result grids.
class KuboListingCard extends StatelessWidget {
  const KuboListingCard({super.key, required this.listing});

  /// Listing data source used to populate the card layout.
  final SyntheticListingRecord listing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ListingPage(listing: listing),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(listing.imageAssetPath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            listing.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${listing.price} | ${listing.locationLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 14,
                color: AppColors.gray,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  listing.sellerLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.gray,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SaveButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${listing.title} saved')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 22,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        child: const AppSvgIcon(
          assetPath: AppIcons.heartSaved,
          size: 16,
          color: AppColors.gray,
        ),
      ),
    );
  }
}
