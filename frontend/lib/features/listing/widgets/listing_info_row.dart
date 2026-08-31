import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ListingInfoRow extends StatelessWidget {
  const ListingInfoRow({super.key, required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gray),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.gray,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
