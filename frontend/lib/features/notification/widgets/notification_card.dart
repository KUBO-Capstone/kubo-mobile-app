import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Builds the compact notification card used in the notification feed.
Widget buildNotificationCard({
  required String title,
  required String message,
  required String date,
  required String time,
  required String image,
}) {
  return Container(
    height: 90,
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              Text(
                '$date, $time',
                style: const TextStyle(
                  color: AppColors.gray,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              image,
              width: 70,
              height: 66,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    width: 70,
                    height: 66,
                    color: AppColors.softBackground,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.gray,
                      size: 30,
                    ),
                  ),
            ),
          ),
        ),
      ],
    ),
  );
}
