import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'app_design_tokens.dart';

class AppTheme {
  // Sleek Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppConstants.backgroundDark,
      primaryColor: AppConstants.primaryDark,
      colorScheme: ColorScheme.dark(
        primary: AppConstants.primaryDark,
        secondary: AppConstants.accentDark,
        surface: AppConstants.surfaceDark,
        onPrimary: Colors.white,
        onSurface: AppConstants.textPrimaryDark,
        onSecondary: Colors.white,
        primaryContainer: AppConstants.primaryDark.withValues(alpha: 0.2),
        secondaryContainer: AppConstants.accentDark.withValues(alpha: 0.2),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppConstants.textPrimaryDark,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: AppConstants.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: AppConstants.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryDark,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppConstants.primaryDark.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppConstants.accentDark,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: const TextStyle(color: AppConstants.textSecondaryDark, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: AppConstants.accentDark, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.accentDark, width: 2.0),
        ),
      ),
      extensions: const [
        AppDesignTokens.dark,
      ],
    );
  }

  // Elegant Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppConstants.backgroundLight,
      primaryColor: AppConstants.primaryLight,
      colorScheme: ColorScheme.light(
        primary: AppConstants.primaryLight,
        secondary: AppConstants.accentLight,
        surface: AppConstants.surfaceLight,
        onPrimary: Colors.white,
        onSurface: AppConstants.textPrimaryLight,
        onSecondary: Colors.white,
        primaryContainer: AppConstants.primaryLight.withValues(alpha: 0.1),
        secondaryContainer: AppConstants.accentLight.withValues(alpha: 0.1),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppConstants.textPrimaryLight,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
        iconTheme: IconThemeData(color: AppConstants.textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: AppConstants.surfaceLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.04), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryLight,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppConstants.primaryLight.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppConstants.accentLight,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: const TextStyle(color: AppConstants.textSecondaryLight, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: AppConstants.primaryLight, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.primaryLight, width: 2.0),
        ),
      ),
      extensions: const [
        AppDesignTokens.light,
      ],
    );
  }
}
