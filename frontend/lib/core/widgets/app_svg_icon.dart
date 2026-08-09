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

  /// Asset path for the SVG file that should be rendered.
  final String assetPath;

  /// Width and height used to keep the icon size consistent across the UI.
  final double size;

  /// Optional tint color applied when the icon needs to match the theme.
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