import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// `PHP 1,323` style, no decimals for whole numbers, two otherwise.
String formatPeso(double value) {
  final whole = value == value.roundToDouble();
  final text = whole ? value.toInt().toString() : value.toStringAsFixed(2);
  final parts = text.split('.');
  final buffer = StringBuffer();
  final digits = parts.first;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return parts.length > 1 ? '$buffer.${parts[1]}' : buffer.toString();
}

/// `Sep 16, 2026` for the "as of" labels. DA publishes daily, so the day
/// matters.
String formatDate(DateTime? date) {
  if (date == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// The +/- column: green ▲ for a rise, red ▼ for a drop, grey dash when
/// there is no previous snapshot to compare with.
class PriceTrendLabel extends StatelessWidget {
  const PriceTrendLabel({super.key, required this.changePct, this.fontSize = 11});

  final double? changePct;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final change = changePct;
    if (change == null) {
      return Text('—', style: TextStyle(color: AppColors.gray, fontSize: fontSize));
    }
    final up = change > 0;
    final flat = change == 0;
    final color = flat ? AppColors.gray : (up ? AppColors.green : Colors.redAccent);
    final icon = flat ? Icons.remove : (up ? Icons.arrow_drop_up : Icons.arrow_drop_down);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fontSize + 5, color: color),
        Text(
          '${up ? '+' : ''}${change.toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Column widths shared by the header and every row so they line up.
const _flexes = <int>[5, 3, 3, 2, 3];

/// Header row: Market | Group | Avg. Price (Php) | Unit | +/-  (the labels
/// are configurable so the product dashboard can say Region | Province/City).
class MarketTableHeader extends StatelessWidget {
  const MarketTableHeader({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _flexes[i],
              child: Text(
                labels[i],
                textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                style: const TextStyle(color: AppColors.black, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// One table row. [leading] is the first column (a name, or a region), then
/// [secondary] (group, or province/city), then price, unit and trend.
class MarketTableRow extends StatelessWidget {
  const MarketTableRow({
    super.key,
    required this.leading,
    required this.secondary,
    required this.price,
    required this.unit,
    required this.changePct,
    this.onTap,
  });

  final String leading;
  final String secondary;
  final double? price;
  final String unit;
  final double? changePct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Expanded(
              flex: _flexes[0],
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      leading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, size: 14, color: AppColors.gray),
                ],
              ),
            ),
            Expanded(
              flex: _flexes[1],
              child: Text(
                secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray, fontSize: 10),
              ),
            ),
            Expanded(
              flex: _flexes[2],
              child: Text(
                price == null ? '—' : formatPeso(price!),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: _flexes[3],
              child: Text(
                unit,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray, fontSize: 11),
              ),
            ),
            Expanded(
              flex: _flexes[4],
              child: Center(child: PriceTrendLabel(changePct: changePct)),
            ),
          ],
        ),
      ),
    );
  }
}
