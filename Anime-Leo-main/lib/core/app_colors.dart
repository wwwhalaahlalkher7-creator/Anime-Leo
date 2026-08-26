import 'package:flutter/material.dart';

/// Centralized app palette.
///
/// Source of truth for every screen's colors — see docs/SETTINGS_SIDEBAR_PLAN.md
/// ("Color palette" section) for where each role is meant to be used. Screens should
/// read colors from `Theme.of(context).colorScheme` (built from these values in
/// `app_theme.dart`) rather than hardcoding hex values directly.
class AppColors {
  AppColors._();

  // Dark theme (primary identity).
  static const background = Color(0xFF05081A);
  static const surface = Color(0xFF10142B);
  static const primary = Color(0xFF4C6EF5);
  static const primaryDark = Color(0xFF003F8F);
  static const highlight = Color(0xFFBAD9F6);
  static const onDark = Color(0xFFF5F7FF);

  // Light theme counterparts — same identity, inverted for a light background.
  static const backgroundLight = Color(0xFFF5F7FF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const onLight = Color(0xFF05081A);
}
