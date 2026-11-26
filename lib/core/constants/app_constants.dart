import 'package:flutter/material.dart';

/// Legacy constants holder.
///
/// Deprecated: All configuration and strings have been migrated to [AppConfig].
/// Color constants are retained temporarily until the design tokens phase.
@Deprecated('Migrated to AppConfig. Color constants retained temporarily until design tokens phase.')
class AppConstants {
  // Design Tokens (Retained temporarily for backwards compatibility)
  static const Color primaryDark = Color(0xFF6C63FF);
  static const Color accentDark = Color(0xFF00E6FF);
  static const Color backgroundDark = Color(0xFF0F0E17);
  static const Color surfaceDark = Color(0xFF1E1C2A);
  static const Color textPrimaryDark = Color(0xFFFFFEFA);
  static const Color textSecondaryDark = Color(0xFFA7A6BA);

  static const Color primaryLight = Color(0xFF4F46E5);
  static const Color accentLight = Color(0xFF0891B2);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
}
