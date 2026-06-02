import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الثيم الأساسي للتطبيق
/// يدعم: RTL، خط Cairo، الألوان المخصصة
class AppTheme {
  AppTheme._();

  // --- الألوان الأساسية ---
  static const Color primaryColor = Color(0xFF1B5E20); // أخضر غامق
  static const Color secondaryColor = Color(0xFFF57F17); // برتقالي/ذهبي
  static const Color accentColor = Color(0xFFE8F5E9); // أخضر فاتح
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color surfaceColor = Color(0xFFF5F5F5);
  static const Color darkSurface = Color(0xFF1E1E1E);

  // --- الثيم الفاتح ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: surfaceColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceColor,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.cairo(fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.cairo(),
        bodyMedium: GoogleFonts.cairo(),
        bodySmall: GoogleFonts.cairo(),
        labelLarge: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        labelSmall: GoogleFonts.cairo(),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
        thickness: 0.5,
      ),
      // RTL support
      textDirection: TextDirection.rtl,
    );
  }

  // --- الثيم الداكن (لاحقاً) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkSurface,
      textDirection: TextDirection.rtl,
    );
  }
}
