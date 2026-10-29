import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Amber used for rating stars across the app.
const Color kuboStarColor = Color(0xFFF5A623);

/// Read-only row of five stars with half-star precision.
class KuboStarRating extends StatelessWidget {
  const KuboStarRating({super.key, required this.rating, this.size = 16, this.color = kuboStarColor});

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rounded = (rating * 2).round() / 2;
    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(5, (index) {
          final position = index + 1;
          final icon = rounded >= position
              ? Icons.star_rounded
              : rounded >= position - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded;
          return Icon(icon, size: size, color: color);
        }),
      ),
    );
  }
}

/// "★ 4.8 · 12 reviews", or "No reviews yet" before the first one.
class KuboRatingLine extends StatelessWidget {
  const KuboRatingLine({super.key, required this.average, required this.count, this.fontSize = 13, this.onTap});

  final double? average;
  final int count;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = average;
    final Widget content;
    if (value == null || count == 0) {
      content = Text('No reviews yet', style: TextStyle(color: AppColors.gray, fontSize: fontSize));
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: fontSize + 3, color: kuboStarColor),
          const SizedBox(width: 3),
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(color: AppColors.black, fontSize: fontSize, fontWeight: FontWeight.w800),
          ),
          Text(
            ' · $count review${count == 1 ? '' : 's'}',
            style: TextStyle(color: AppColors.gray, fontSize: fontSize),
          ),
        ],
      );
    }
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: content),
    );
  }
}

/// Five large tappable stars for writing a review.
class KuboStarRatingInput extends StatelessWidget {
  const KuboStarRatingInput({super.key, required this.value, required this.onChanged, this.size = 44});

  /// 0 when nothing is picked yet.
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(5, (index) {
        final star = index + 1;
        final filled = star <= value;
        return Semantics(
          button: true,
          selected: star == value,
          label: '$star star${star == 1 ? '' : 's'}',
          child: InkResponse(
            onTap: () => onChanged(star),
            radius: size * 0.6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedScale(
                scale: filled ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: filled ? kuboStarColor : AppColors.border,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
