import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/data/market_service.dart';
import 'market_price_table.dart';

/// The green gradient card from PPA 3–6: highest / lowest / nationwide /
/// SRP for a product, either nationwide (dashboard) or for one area (map).
class MarketSummaryCard extends StatelessWidget {
  const MarketSummaryCard({super.key, required this.product, this.area});

  final MarketProductDetail product;

  /// When set, the card describes this area instead of the whole country.
  final MarketAreaPrice? area;

  String _peso(double? value) => value == null ? '—' : '₱${formatPeso(value)}/${product.unit}';

  @override
  Widget build(BuildContext context) {
    final area = this.area;
    final title = area == null ? product.name : area.title;
    final highest = area?.highestPrice ?? product.highestPrice;
    final lowest = area?.lowestPrice ?? product.lowestPrice;
    final source = area?.source ?? product.source;
    // A region card says how many markets its numbers cover; a single
    // market has one price, so highest/lowest would just repeat it.
    final isSingleMarket = area != null && !area.isRegion;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFDCEFE3)],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.black, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'as of ${formatDate(area?.asOf ?? product.asOf)}',
                style: const TextStyle(color: AppColors.gray, fontSize: 10),
              ),
            ],
          ),
          if (area != null) ...[
            const SizedBox(height: 4),
            _Line(label: 'Product', value: product.name),
          ],
          const SizedBox(height: 8),
          if (isSingleMarket)
            _Line(label: 'Price at this market', value: _peso(area.avgPrice))
          else ...[
            _Line(label: 'Highest Price', value: _peso(highest)),
            _Line(label: 'Lowest Price', value: _peso(lowest)),
            if (area != null)
              _Line(label: 'Markets covered', value: '${area.sampleSize}'),
          ],
          const SizedBox(height: 6),
          _Line(label: 'Nationwide Avg. Price', value: _peso(product.nationwideAvg)),
          _Line(label: 'DTI SRP', value: product.dtiSrp == null ? 'Not covered' : _peso(product.dtiSrp)),
          const SizedBox(height: 6),
          _Line(label: 'Classification', value: product.classification),
          _Line(label: 'Group(s)', value: product.groups.join(', ')),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                source == marketSourceDa ? Icons.verified_outlined : Icons.science_outlined,
                size: 12,
                color: AppColors.gray,
              ),
              const SizedBox(width: 4),
              Text(
                'Source: ${marketSourceLabel(source)}',
                style: const TextStyle(color: AppColors.gray, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.black, fontSize: 11, height: 1.35),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.gray)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
