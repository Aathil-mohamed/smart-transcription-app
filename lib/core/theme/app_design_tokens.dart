import 'package:flutter/material.dart';

@immutable
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  // Brand & Semantic Colors
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color error;
  final Color success;
  final Color warning;

  // Spacing (Logical pixels)
  final double spaceXs; // 4
  final double spaceSm; // 8
  final double spaceMd; // 16
  final double spaceLg; // 24
  final double spaceXl; // 32
  final double spaceXxl; // 48

  // Radii
  final double radiusSm; // 8
  final double radiusMd; // 12
  final double radiusLg; // 16
  final double radiusXl; // 24
  final double radiusFull; // 999

  // Typography Scale
  final double fontXs; // 11
  final double fontSm; // 13
  final double fontMd; // 15
  final double fontLg; // 18
  final double fontXl; // 22
  final double fontDisplay; // 32

  // Animation Durations
  final Duration animFast; // 150ms
  final Duration animMedium; // 300ms
  final Duration animSlow; // 500ms

  const AppDesignTokens({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.error,
    required this.success,
    required this.warning,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusFull,
    required this.fontXs,
    required this.fontSm,
    required this.fontMd,
    required this.fontLg,
    required this.fontXl,
    required this.fontDisplay,
    required this.animFast,
    required this.animMedium,
    required this.animSlow,
  });

  static const dark = AppDesignTokens(
    primary: Color(0xFF6C63FF),
    secondary: Color(0xFF8B5CF6),
    accent: Color(0xFF00E6FF),
    background: Color(0xFF0F0E17),
    surface: Color(0xFF1E1C2A),
    surfaceSubtle: Color(0xFF282538),
    textPrimary: Color(0xFFFFFEFA),
    textSecondary: Color(0xFFA7A6BA),
    textMuted: Color(0xFF6E6D7E),
    border: Color(0x1AFFFFFF),
    error: Color(0xFFFF5252),
    success: Color(0xFF00C853),
    warning: Color(0xFFFFB300),
    spaceXs: 4.0,
    spaceSm: 8.0,
    spaceMd: 16.0,
    spaceLg: 24.0,
    spaceXl: 32.0,
    spaceXxl: 48.0,
    radiusSm: 8.0,
    radiusMd: 12.0,
    radiusLg: 16.0,
    radiusXl: 24.0,
    radiusFull: 999.0,
    fontXs: 11.0,
    fontSm: 13.0,
    fontMd: 15.0,
    fontLg: 18.0,
    fontXl: 22.0,
    fontDisplay: 32.0,
    animFast: Duration(milliseconds: 150),
    animMedium: Duration(milliseconds: 300),
    animSlow: Duration(milliseconds: 500),
  );

  static const light = AppDesignTokens(
    primary: Color(0xFF4F46E5),
    secondary: Color(0xFF6366F1),
    accent: Color(0xFF0891B2),
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    border: Color(0x0F000000),
    error: Color(0xFFD32F2F),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFED6C02),
    spaceXs: 4.0,
    spaceSm: 8.0,
    spaceMd: 16.0,
    spaceLg: 24.0,
    spaceXl: 32.0,
    spaceXxl: 48.0,
    radiusSm: 8.0,
    radiusMd: 12.0,
    radiusLg: 16.0,
    radiusXl: 24.0,
    radiusFull: 999.0,
    fontXs: 11.0,
    fontSm: 13.0,
    fontMd: 15.0,
    fontLg: 18.0,
    fontXl: 22.0,
    fontDisplay: 32.0,
    animFast: Duration(milliseconds: 150),
    animMedium: Duration(milliseconds: 300),
    animSlow: Duration(milliseconds: 500),
  );

  @override
  ThemeExtension<AppDesignTokens> copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? error,
    Color? success,
    Color? warning,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    double? fontXs,
    double? fontSm,
    double? fontMd,
    double? fontLg,
    double? fontXl,
    double? fontDisplay,
    Duration? animFast,
    Duration? animMedium,
    Duration? animSlow,
  }) {
    return AppDesignTokens(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXxl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
      fontXs: fontXs ?? this.fontXs,
      fontSm: fontSm ?? this.fontSm,
      fontMd: fontMd ?? this.fontMd,
      fontLg: fontLg ?? this.fontLg,
      fontXl: fontXl ?? this.fontXl,
      fontDisplay: fontDisplay ?? this.fontDisplay,
      animFast: animFast ?? this.animFast,
      animMedium: animMedium ?? this.animMedium,
      animSlow: animSlow ?? this.animSlow,
    );
  }

  @override
  ThemeExtension<AppDesignTokens> lerp(
    covariant ThemeExtension<AppDesignTokens>? other,
    double t,
  ) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t) ?? surfaceSubtle,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      error: Color.lerp(error, other.error, t) ?? error,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      spaceXs: (spaceXs + (other.spaceXs - spaceXs) * t),
      spaceSm: (spaceSm + (other.spaceSm - spaceSm) * t),
      spaceMd: (spaceMd + (other.spaceMd - spaceMd) * t),
      spaceLg: (spaceLg + (other.spaceLg - spaceLg) * t),
      spaceXl: (spaceXl + (other.spaceXl - spaceXl) * t),
      spaceXxl: (spaceXxl + (other.spaceXxl - spaceXxl) * t),
      radiusSm: (radiusSm + (other.radiusSm - radiusSm) * t),
      radiusMd: (radiusMd + (other.radiusMd - radiusMd) * t),
      radiusLg: (radiusLg + (other.radiusLg - radiusLg) * t),
      radiusXl: (radiusXl + (other.radiusXl - radiusXl) * t),
      radiusFull: (radiusFull + (other.radiusFull - radiusFull) * t),
      fontXs: (fontXs + (other.fontXs - fontXs) * t),
      fontSm: (fontSm + (other.fontSm - fontSm) * t),
      fontMd: (fontMd + (other.fontMd - fontMd) * t),
      fontLg: (fontLg + (other.fontLg - fontLg) * t),
      fontXl: (fontXl + (other.fontXl - fontXl) * t),
      fontDisplay: (fontDisplay + (other.fontDisplay - fontDisplay) * t),
      animFast: t < 0.5 ? animFast : other.animFast,
      animMedium: t < 0.5 ? animMedium : other.animMedium,
      animSlow: t < 0.5 ? animSlow : other.animSlow,
    );
  }
}

extension AppDesignTokensExtension on BuildContext {
  AppDesignTokens get tokens {
    return Theme.of(this).extension<AppDesignTokens>() ?? AppDesignTokens.dark;
  }
}
