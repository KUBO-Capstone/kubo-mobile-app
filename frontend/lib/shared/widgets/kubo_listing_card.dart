import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../features/listing/screens/listing_page.dart';
import '../data/synthetic_records.dart';
import 'kubo_save_button.dart';

/// Shared listing card used across explore and search result grids.
class KuboListingCard extends StatelessWidget {
  const KuboListingCard({
    super.key,
    required this.listing,
    this.onManage,
    this.onChanged,
  });

  /// Listing data source used to populate the card layout.
  final SyntheticListingRecord listing;

  /// Seller-only: replaces the save heart with a menu button that opens the
  /// manage sheet. Null on cards the viewer does not own.
  final VoidCallback? onManage;

  /// Raised when the listing page popped after the seller changed or removed
  /// the listing, so the owning grid can reload.
  final VoidCallback? onChanged;

  Future<void> _open(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ListingPage(listing: listing)),
    );
    if (changed == true) {
      onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  listing.imageAssetPath.startsWith('http')
                      ? Image.network(listing.imageAssetPath, fit: BoxFit.cover)
                      : Image.asset(listing.imageAssetPath, fit: BoxFit.cover),
                  // Archived listings only show on the seller's own profile;
                  // dim them so the grid reads at a glance.
                  if (listing.isSoldOut) ...[
                    const ColoredBox(color: Color(0x66FFFFFF)),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Sold out',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
              if (onManage != null)
                _ManageButton(onPressed: onManage!)
              else
                KuboSaveButton(listing: listing, iconSize: 16),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three-dot button shown in place of the heart on the seller's own cards.
class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 22,
      child: const SizedBox(
        width: 26,
        height: 26,
        child: Icon(Icons.more_vert, size: 18, color: AppColors.gray),
      ),
    );
  }
}
