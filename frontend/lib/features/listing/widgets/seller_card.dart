import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';
import '../../profile/screens/profile_page.dart';

/// Seller box on the listing page. Tapping it opens the seller's profile;
/// mock records carry no seller id, so for them the box is static.
class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.listing});

  final SyntheticListingRecord listing;

  void _openSellerProfile(BuildContext context) {
    final sellerId = listing.sellerId;
    if (sellerId == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ProfilePage.forSeller(
              sellerId: sellerId,
              sellerName: listing.sellerLabel,
              locationLabel: listing.locationLabel,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = listing.sellerId != null;

    return Material(
      color: AppColors.softBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen ? () => _openSellerProfile(context) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 28,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.sellerLabel,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canOpen ? 'View seller profile' : 'Verified local grower',
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpen)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.gray,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
