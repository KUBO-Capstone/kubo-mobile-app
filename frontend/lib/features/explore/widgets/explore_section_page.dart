import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ExploreSectionPage extends StatelessWidget {
  const ExploreSectionPage({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}