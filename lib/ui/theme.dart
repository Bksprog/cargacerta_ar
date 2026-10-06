import 'package:flutter/material.dart';

/// Paleta extraída do infográfico do CargaCerta AR.
abstract final class AppColors {
  static const Color navy = Color(0xFF0B2D5C);
  static const Color teal = Color(0xFF0E8C7F);
  static const Color orange = Color(0xFFF28C28);
  static const Color blue = Color(0xFF2A62B5);
  static const Color purple = Color(0xFF7C5CBF);
  static const Color gold = Color(0xFFF2B705);
  static const Color background = Color(0xFFF3F8FC);
  static const Color border = Color(0xFFD5E2EE);
  static const Color ink = Color(0xFF10233F);
  static const Color muted = Color(0xFF52667F);
  static const Color danger = Color(0xFFC62828);

  /// Cor de cada etapa: Calibrar, Mapear, Classificar, Recomendar.
  static const List<Color> steps = <Color>[navy, teal, orange, navy];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.navy).copyWith(
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.teal,
    tertiary: AppColors.orange,
    surface: Colors.white,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.navy, 2),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.navy.withAlpha(28),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
