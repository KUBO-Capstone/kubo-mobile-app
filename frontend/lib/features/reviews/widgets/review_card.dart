import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/data/review_service.dart';
import '../../../shared/widgets/kubo_star_rating.dart';

/// One review on a profile or order: who wrote it and from which side of
/// the deal, the stars, tags, comment, and the produce it was about.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.showProduct = true, this.margin});

  final ReviewRecord review;

  /// Off on the order page, which already shows the produce.
  final bool showProduct;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReviewerAvatar(name: review.reviewerName, photoUrl: review.reviewerPhotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.reviewerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoleChip(role: review.reviewerRole),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        KuboStarRating(rating: review.rating.toDouble(), size: 15),
                        const SizedBox(width: 8),
                        Text(timeAgo(review.createdAt), style: const TextStyle(color: AppColors.gray, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in review.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ReviewTags.labelOf(tag),
                      style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(review.comment, style: const TextStyle(color: AppColors.black, fontSize: 14, height: 1.45)),
          ],
          if (showProduct) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: review.productImage == null
                        ? const ColoredBox(color: AppColors.softBackground, child: Icon(Icons.eco_outlined, size: 18, color: AppColors.gray))
                        : Image.network(
                            review.productImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: AppColors.softBackground, child: Icon(Icons.eco_outlined, size: 18, color: AppColors.gray)),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    review.cropName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Photo, or the first letter of the name on a tinted circle.
class ReviewerAvatar extends StatelessWidget {
  const ReviewerAvatar({super.key, required this.name, this.photoUrl, this.radius = 20});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.green.withValues(alpha: 0.12),
      child: Text(initial, style: TextStyle(color: AppColors.green, fontSize: radius * 0.85, fontWeight: FontWeight.w800)),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final ReviewerRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.softBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        role == ReviewerRole.buyer ? 'Buyer' : 'Seller',
        style: const TextStyle(color: AppColors.gray, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
