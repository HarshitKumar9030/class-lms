import 'package:flutter/material.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = AppPalette(
      background: dark ? AppColors.darkBackground : AppColors.lightBackground,
      surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
      muted: dark ? AppColors.darkMuted : AppColors.lightMuted,
      text: dark ? AppColors.darkText : AppColors.lightText,
      secondary: dark ? AppColors.darkSecondary : AppColors.lightSecondary,
      accent: dark ? AppColors.darkAccent : AppColors.accent,
    );
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: brightness,
          surface: palette.surface,
        ).copyWith(
          primary: palette.accent,
          onPrimary: dark ? AppColors.darkBackground : Colors.white,
          secondary: dark ? AppColors.sunshine : AppColors.accent,
          onSecondary: dark ? AppColors.darkBackground : Colors.white,
          onSurface: palette.text,
          surfaceContainerHighest: palette.muted,
        );
    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      colorScheme: scheme,
      extensions: [palette],
      textTheme: base.textTheme.copyWith(
        displaySmall: TextStyle(
          fontSize: 32,
          height: 1.14,
          letterSpacing: -0.8,
          fontWeight: FontWeight.w700,
          color: palette.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          height: 1.2,
          letterSpacing: -0.5,
          fontWeight: FontWeight.w700,
          color: palette.text,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.25,
          letterSpacing: -0.3,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: palette.text),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: palette.text),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: palette.secondary,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 0,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
