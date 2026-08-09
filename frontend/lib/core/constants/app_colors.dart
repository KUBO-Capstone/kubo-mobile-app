import 'package:flutter/material.dart';

// Centralized brand colors used across the Flutter frontend.
abstract final class AppColors {
  /// Primary green used for calls to action, selected states, and brand emphasis.
  static const green = Color(0xFF007537);
  /// Main text and icon color for high-contrast foreground content.
  static const black = Color(0xFF221F1F);
  /// Secondary text color for helper copy, metadata, and inactive elements.
  static const gray = Color(0xFF7D7B7B);
  /// White surface color used for cards, sheets, and the general page background.
  static const white = Color(0xFFFFFFFF);
  /// Soft cream background used for light panels and fallback containers.
  static const softBackground = Color(0xFFF7F6F3);
  /// Neutral border color for dividers, chips, and input outlines.
  static const border = Color(0xFFE6E2DC);
}