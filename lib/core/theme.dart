import 'package:flutter/material.dart';

import 'constants.dart';

class AppColors {
  static const background = Color(0xFFFAF7EF);
  static const accent = Color(0xFF006874);
  static const success = Color(0xFF3E7050);
  static const warning = Color(0xFF955C00);
  static const danger = Color(0xFFBA1A1A);
  static const neutral = Color(0xFF6B6B63);
  static const cardBackground = Colors.white;
  static const textPrimary = Color(0xFF2B2B26);
  static const textSecondary = neutral;
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    surface: AppColors.background,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: AppColors.cardBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    margin: EdgeInsets.zero,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : null,
    ),
    trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
          ? AppColors.accent.withValues(alpha: 0.5)
          : null,
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.cardBackground,
    selectedItemColor: AppColors.accent,
    unselectedItemColor: AppColors.textSecondary,
    type: BottomNavigationBarType.fixed,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textPrimary),
    bodySmall: TextStyle(color: AppColors.textSecondary),
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.textPrimary,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppColors.textPrimary,
    ),
  ),
);
