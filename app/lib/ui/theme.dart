import 'package:flutter/material.dart';

/// Colores de la marca (provisionales hasta tener nombre y logo).
abstract final class AppColors {
  static const brand = Color(0xFF0B7A5A);
  static const cheap = Color(0xFF1E8E3E);
  static const mid = Color(0xFFE0A100);
  static const expensive = Color(0xFFD93025);
  static const charger = Color(0xFF1A73E8);
  static const parking = Color(0xFF5F6368);
  static const group = Color(0xFF37474F);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    chipTheme: ChipThemeData(side: BorderSide(color: scheme.outlineVariant)),
  );
}

/// Color de un precio según su posición entre los visibles (barato → caro).
Color priceColor(double price, double min, double max) {
  if (max - min < 0.005) return AppColors.cheap;
  final t = (price - min) / (max - min);
  if (t < 0.34) return AppColors.cheap;
  if (t < 0.67) return AppColors.mid;
  return AppColors.expensive;
}
