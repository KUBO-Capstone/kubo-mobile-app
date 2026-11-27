import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'kubo_image.dart';

/// A person's profile photo in a circle (or rounded square), or a person
/// icon when they have none or it fails to load.
class KuboAvatar extends StatelessWidget {
  const KuboAvatar({
    super.key,
    required this.photoUrl,
    required this.size,
    this.background = AppColors.black,
    this.iconColor = AppColors.white,
    this.borderRadius,
  });

  final String? photoUrl;
  final double size;
  final Color background;
  final Color iconColor;

  /// Null draws a circle.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
      ),
      child: Icon(Icons.person_outline, size: size * 0.55, color: iconColor),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    final image = KuboImage(url, width: size, height: size, errorIcon: Icons.person_outline);
    return borderRadius == null
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
