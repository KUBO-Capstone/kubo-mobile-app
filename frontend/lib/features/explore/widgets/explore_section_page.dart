import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Generic placeholder page used by explore shortcuts such as search or profile.
class ExploreSectionPage extends StatelessWidget {
  const ExploreSectionPage({super.key, required this.title, required this.message});

  /// Page title shown in the app bar and the placeholder body text.
  final String title;

  /// Supporting message that explains the future destination or feature.
  final String message;

  @override
  // Builds a simple page that shows the chosen placeholder title and message.
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