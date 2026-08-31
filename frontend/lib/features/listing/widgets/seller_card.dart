import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/synthetic_records.dart';

class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.listing});

  final SyntheticListingRecord listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
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
                const Text(
                  'Verified local grower',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.gray,
          ),
        ],
      ),
    );
  }
}
