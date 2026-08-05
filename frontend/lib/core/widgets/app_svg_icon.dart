import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Small helper widget that renders an SVG asset at a fixed size and optional tint.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon({
    super.key,
    required this.assetPath,
    required this.size,
    this.color,
  });

  final String assetPath;
  final double size;
  final Color? color;

  @override
  // Loads the SVG from assets and applies an optional color filter for theme control.
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}