import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/review_service.dart';
import '../../../shared/widgets/kubo_star_rating.dart';

/// Big average, stars and count on the left; one bar per star on the right.
class RatingSummaryCard extends StatelessWidget {
  const RatingSummaryCard({super.key, required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final average = summary.average ?? 0;
    final highest = summary.breakdown.values.fold<int>(0, (max, value) => value > max ? value : max);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(color: AppColors.black, fontSize: 40, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(height: 6),
              KuboStarRating(rating: average, size: 16),
              const SizedBox(height: 4),
              Text(
                '${summary.count} review${summary.count == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.gray, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$star', style: const TextStyle(color: AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.star_rounded, size: 12, color: kuboStarColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: highest == 0 ? 0 : (summary.breakdown[star] ?? 0) / highest,
                              minHeight: 7,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(kuboStarColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${summary.breakdown[star] ?? 0}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: AppColors.gray, fontSize: 12),
                          ),
                        ),
                      ],
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
