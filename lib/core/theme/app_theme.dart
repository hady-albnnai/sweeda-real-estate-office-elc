import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepBlack = Color(0xFF121212);
  static const Color lightGold = Color(0xFFF9E4B7);
  static const Color surfaceBlack = Color(0xFF1E1E1E);
  static const Color errorRed = Color(0xFFCF6679);
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color textGrey = Color(0xFFB0B0B0);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryGold,
      scaffoldBackgroundColor: deepBlack,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: primaryGold,
        surface: surfaceBlack,
        background: deepBlack,
        error: errorRed,
        onPrimary: deepBlack,
        onSecondary: deepBlack,
        onSurface: textWhite,
        onBackground: textWhite,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: textWhite,
          displayColor: primaryGold,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBlack,
        foregroundColor: primaryGold,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: deepBlack,
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        labelStyle: const TextStyle(color: textGrey),
      ),
      cardTheme: CardTheme(
        color: surfaceBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: primaryGold, width: 0.5),
        ),
      ),
    );
  }
}
