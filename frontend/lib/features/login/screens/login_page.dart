import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_svg_icon.dart';
import '../../shell/screens/app_shell.dart';
import '../services/auth_service.dart';
import 'create_account_page.dart';
import 'email_login_page.dart';
import '../widgets/kubo_hero_image.dart';

/// Landing page that introduces Kubo and offers sign-in and sign-up entry points.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  /// Root route used by the app shell to open the login landing screen.
  static const routeName = '/';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Google sign-in is under way: the button shows a spinner and ignores taps.
  bool _isGoogleSigningIn = false;

  // Google's account picker, then the backend, then into the app the same
  // way an email login goes. Backing out of the picker changes nothing.
  Future<void> _continueWithGoogle() async {
    if (_isGoogleSigningIn) return;
    setState(() => _isGoogleSigningIn = true);
    final authService = AuthService();
    try {
      await authService.loginWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(AppShell.route(), (route) => false);
    } on GoogleSignInCancelled {
      // The user closed the picker; nothing to say.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      authService.dispose();
      if (mounted) setState(() => _isGoogleSigningIn = false);
    }
  }

  @override
  // Builds the login landing layout with branding, explanation text, and auth options.
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
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                            isLoading: _isGoogleSigningIn,
                            onPressed: _continueWithGoogle,
                          ),
                          const SizedBox(height: 10),
                          _AuthOptionButton(
                            label: 'Continue with Email',
                            icon: _AuthIcon.email,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const EmailLoginPage()),
                              );
                            },
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
}

/// Internal enum that identifies which provider icon should be rendered.
enum _AuthIcon { google, email }

/// Full-width outlined button used for each third-party or email login action.
class _AuthOptionButton extends StatelessWidget {
  const _AuthOptionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  /// Label shown in the center of the button.
  final String label;

  /// Icon variant that determines which provider glyph is rendered.
  final _AuthIcon icon;

  /// Tap callback that launches the selected auth flow.
  final VoidCallback onPressed;

  /// Shows a spinner in place of the icon and ignores taps.
  final bool isLoading;

  @override
  // Renders the branded auth button with an icon and centered label.
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          // Same look while loading; only the icon turns into a spinner.
          disabledBackgroundColor: AppColors.white,
          disabledForegroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: isLoading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green),
              )
            else
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

/// Icon widget that swaps its visual based on the chosen auth provider.
class _AuthButtonIcon extends StatelessWidget {
  const _AuthButtonIcon({required this.icon});

  /// Current provider icon selection used to decide which symbol to draw.
  final _AuthIcon icon;

  @override
  // Returns the provider-specific icon or glyph for the auth button.
  Widget build(BuildContext context) {
    switch (icon) {
      case _AuthIcon.google:
        return const AppSvgIcon(assetPath: AppIcons.googleLogo, size: 20);
      case _AuthIcon.email:
        return const Icon(
          Icons.email_outlined,
          size: 20,
          color: AppColors.black,
        );
    }
  }
}