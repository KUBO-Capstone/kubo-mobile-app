import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'auth_method_page.dart';
import 'create_account_page.dart';
import 'widgets/kubo_hero_image.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const routeName = '/';

  @override
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
                    // 1. Full-width hero image 
                    const KuboHeroImage(),
                    const SizedBox(height: 12),

                    // 2. Wrap all remaining content in Padding
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const Text(
                            'KUBO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'Skip the grocery store lines and get fresh, farm-certified goods delivered straight from local fields to your family\'s table',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.black,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _AuthOptionButton(
                            label: 'Continue with Google',
                            icon: _AuthIcon.google,
                            onPressed: () => _openAuthMethod(context, 'Google'),
                          ),
                          const SizedBox(height: 10),
                          _AuthOptionButton(
                            label: 'Continue with Facebook',
                            icon: _AuthIcon.facebook,
                            onPressed: () => _openAuthMethod(context, 'Facebook'),
                          ),
                          const SizedBox(height: 10),
                          _AuthOptionButton(
                            label: 'Continue with Email',
                            icon: _AuthIcon.email,
                            onPressed: () => _openAuthMethod(context, 'Email'),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CreateAccountPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Create account',
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

  void _openAuthMethod(BuildContext context, String methodName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthMethodPage(methodName: methodName),
      ),
    );
  }
}

enum _AuthIcon { google, facebook, email }

class _AuthOptionButton extends StatelessWidget {
  const _AuthOptionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final _AuthIcon icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AuthButtonIcon(icon: icon),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButtonIcon extends StatelessWidget {
  const _AuthButtonIcon({required this.icon});

  final _AuthIcon icon;

  @override
  Widget build(BuildContext context) {
    switch (icon) {
      case _AuthIcon.google:
        return const Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4285F4),
          ),
        );
      case _AuthIcon.facebook:
        return const Icon(
          Icons.facebook,
          size: 20,
          color: Color(0xFF1877F2),
        );
      case _AuthIcon.email:
        return const Icon(
          Icons.email_outlined,
          size: 20,
          color: AppColors.black,
        );
    }
  }
}