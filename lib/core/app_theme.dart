import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Builds the app's [ThemeData] for a given [brightness] from the centralized
/// [AppColors] palette. Both `theme` and `darkTheme` in `main.dart` should come
/// from here so every screen shares one color source.
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onDark,
    secondary: AppColors.primaryDark,
    onSecondary: AppColors.onDark,
    tertiary: AppColors.highlight,
    onTertiary: AppColors.background,
    surface: isDark ? AppColors.surface : AppColors.surfaceLight,
    onSurface: isDark ? AppColors.onDark : AppColors.onLight,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.background : AppColors.backgroundLight,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      foregroundColor: isDark ? AppColors.onDark : AppColors.onLight,
      elevation: 0,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
    ),
    cardTheme: CardThemeData(
      color: isDark ? AppColors.surface : AppColors.surfaceLight,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary.withValues(alpha: 0.5)
            : null,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
