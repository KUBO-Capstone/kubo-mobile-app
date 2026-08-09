import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'get_started_page.dart';
import '../widgets/kubo_hero_image.dart';

/// Intermediate onboarding page that leads into the detailed profile form.
class CreateAccountPage extends StatelessWidget {
  const CreateAccountPage({super.key});

  /// Route name used when the app pushes the create-account introduction.
  static const routeName = '/create-account';

  @override
  // Builds the account-creation landing page and its navigation controls.
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const KuboHeroImage(),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          const Text(
                            'KUBO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'First time here?\nWe\'ll help you get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.black,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
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
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const GetStartedPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create account',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Already have an account?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.gray,
                              fontSize: 12,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Back to login',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}