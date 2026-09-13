import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette extracted from design:
  // Background: #F5ECDD (Warm Cream / Biscuit)
  // Main Text: #111111 (Deep Charcoal / Black)
  // Highlight / Primary Accent: #B45309 (Rich Warm Amber / Terracotta)
  
  static const Color background = Color(0xFFF5ECDD);
  static const Color mainText = Color(0xFF111111);
  static const Color primary = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color primaryDark = Color(0xFF78350F);

  static const Color cardBg = Colors.white;
  static const Color surfaceLight = Color(0xFFEFE6D5);
  static const Color textMuted = Color(0xFF666666);
  static const Color border = Color(0xFFE5D5C0);

  // Status colors tuned to harmony
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFB91C1C);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0369A1);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: cardBg,
        onPrimary: Colors.white,
        onSurface: mainText,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: mainText,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: mainText),
        titleTextStyle: TextStyle(
          color: mainText,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mainText,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        helperStyle: const TextStyle(color: textMuted, fontSize: 12),
        prefixIconColor: primary,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}
