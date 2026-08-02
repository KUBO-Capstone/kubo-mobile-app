import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  static const routeName = '/get-started';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Started'),
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'This subpage is ready to be replaced with the next onboarding step.',
            textAlign: TextAlign.center,
            style: TextStyle(
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