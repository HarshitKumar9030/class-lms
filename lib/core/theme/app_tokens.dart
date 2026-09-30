import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const page = 24.0;
  static const section = 32.0;
  static const large = 40.0;
}

abstract final class AppRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 20.0;
  static const sheet = 24.0;
}

abstract final class AppColors {
  static const accent = Color(0xFF3269A8);
  static const lightBackground = Color(0xFFF8F8F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFF0F1F0);
  static const lightText = Color(0xFF17191B);
  static const lightSecondary = Color(0xFF697078);
  static const darkBackground = Color(0xFF101113);
  static const darkSurface = Color(0xFF1B1D20);
  static const darkMuted = Color(0xFF292C30);
  static const darkText = Color(0xFFF4F5F6);
  static const darkSecondary = Color(0xFFA5ABB1);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color muted;
  final Color text;
  final Color secondary;
  final Color accent;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.muted,
    required this.text,
    required this.secondary,
    required this.accent,
  });

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? muted,
    Color? text,
    Color? secondary,
    Color? accent,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    muted: muted ?? this.muted,
    text: text ?? this.text,
    secondary: secondary ?? this.secondary,
    accent: accent ?? this.accent,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
