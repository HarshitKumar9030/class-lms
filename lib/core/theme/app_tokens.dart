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
  static const accent = Color(0xFFB84325);
  static const darkAccent = Color(0xFFFFB67E);
  static const sunshine = Color(0xFFFFC45A);
  static const lightBackground = Color(0xFFFFF9F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xFFFFEDE0);
  static const lightText = Color(0xFF352825);
  static const lightSecondary = Color(0xFF75615A);
  static const darkBackground = Color(0xFF1F1B1B);
  static const darkSurface = Color(0xFF2C2423);
  static const darkMuted = Color(0xFF3D302C);
  static const darkText = Color(0xFFFFF8F1);
  static const darkSecondary = Color(0xFFD3BEB1);
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
