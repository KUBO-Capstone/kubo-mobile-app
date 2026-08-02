import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';

class KuboHeroImage extends StatelessWidget {
  const KuboHeroImage({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Image.asset(
        AppAssets.kuboHero,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.softBackground,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.cabin_rounded, size: 72, color: AppColors.green),
                  SizedBox(height: 12),
                  Text(
                    'Add the Kubo illustration to\nassets/images/kubo_house.jpg',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gray,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}