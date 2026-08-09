import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../explore/screens/explore_page.dart';

/// Placeholder page that represents a third-party or email auth flow.
class AuthMethodPage extends StatelessWidget {
  const AuthMethodPage({super.key, required this.methodName});

  /// Provider name displayed in the app bar and the instructional body text.
  final String methodName;

  @override
  // Builds a simple confirmation page before continuing into the explore area.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Continue with $methodName'),
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.verified_user_outlined, size: 72, color: AppColors.green),
            const SizedBox(height: 24),
            Text(
              '$methodName login flow is ready for the next integration step.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const ExplorePage(initialLocationLabel: 'Caybiga'),
                    ),
                  );
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}