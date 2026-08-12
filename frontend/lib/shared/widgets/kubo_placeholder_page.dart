import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Centered placeholder content that can be embedded in a scaffold or reused standalone.
class KuboPlaceholderContent extends StatelessWidget {
  const KuboPlaceholderContent({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.construction_outlined,
  });

  /// Title shown above the supporting copy.
  final String title;

  /// Supporting copy that explains the future screen.
  final String message;

  /// Icon shown above the placeholder copy.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppColors.green),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gray,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic placeholder page for destinations that still need product work.
class KuboPlaceholderPage extends StatelessWidget {
  const KuboPlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.construction_outlined,
  });

  /// Title shown in the app bar and the main body.
  final String title;

  /// Supporting copy that explains the future screen.
  final String message;

  /// Icon shown above the placeholder copy.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: KuboPlaceholderContent(title: title, message: message, icon: icon),
    );
  }
}
