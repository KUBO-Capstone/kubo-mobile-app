import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/market_service.dart';
import '../../market/screens/market_product_page.dart';

/// One line under the asking price: the Market Watch reference for this crop
/// in the seller's region, with an above / below market tag. This is the
/// buyer's overprice check. Renders nothing when there is no reference or
/// the units differ (a per-piece listing against a per-kg price says nothing).
class MarketReferenceLine extends StatelessWidget {
  const MarketReferenceLine({
    super.key,
    required this.reference,
    required this.askingPrice,
    required this.unit,
  });

  final MarketReference? reference;
  final double? askingPrice;
  final String? unit;

  /// Within this band of the reference the price reads as "at market".
  static const _tolerance = 0.05;

  @override
  Widget build(BuildContext context) {
    final ref = reference;
    final asking = askingPrice;
    final comparison = ref?.comparisonPrice;
    if (ref == null || asking == null || comparison == null || unit != ref.unit) {
      return const SizedBox.shrink();
    }

    final diff = (asking - comparison) / comparison;
    final String tag;
    final Color tagColor;
    if (diff > _tolerance) {
      tag = '${(diff * 100).toStringAsFixed(0)}% above market';
      tagColor = Colors.redAccent;
    } else if (diff < -_tolerance) {
      tag = '${(diff.abs() * 100).toStringAsFixed(0)}% below market';
      tagColor = AppColors.green;
    } else {
      tag = 'At market price';
      tagColor = AppColors.gray;
    }
    final scope = ref.region != null && ref.regionAvg != null ? 'in ${ref.region}' : 'nationwide';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MarketProductPage(productId: ref.productId, productName: ref.name),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                style: TextStyle(color: tagColor, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Market avg PHP ${comparison.toStringAsFixed(comparison == comparison.roundToDouble() ? 0 : 2)}/${ref.unit} $scope · ${ref.name}',
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.gray),
          ],
        ),
      ),
    );
  }
}
