import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepBlack = Color(0xFF121212);
  static const Color scaffoldBackground = Color(0xFFFFFBF2);
  static const Color lightGold = Color(0xFFF9E4B7);
  static const Color surfaceBlack = Color(0xFFFFFFFF);
  static const Color errorRed = Color(0xFFB3261E);
  static const Color textWhite = Color(0xFF17130A);
  static const Color textGrey = Color(0xFF6F6656);

  static OverlayEntry? _activeMessageEntry;

  /// يعرض الرسائل فوق كل الطبقات (Dialogs / BottomSheets) بدل SnackBar العادي
  /// الذي كان يظهر أحياناً خلف النوافذ المنبثقة.
  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
      return;
    }

    hideSnackBar(context);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final media = MediaQuery.maybeOf(ctx);
        final top = (media?.padding.top ?? 0) + 12;
        final width = media?.size.width ?? 360;
        final isWide = width > 700;
        final bg = snackBar.backgroundColor ?? const Color(0xFF1E1A12);
        final fg = bg.computeLuminance() > 0.55 ? deepBlack : Colors.white;

        return Positioned(
          top: top,
          left: isWide ? (width - 560) / 2 : 16,
          right: isWide ? (width - 560) / 2 : 16,
          child: SafeArea(
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryGold.withOpacity(0.35)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bg == errorRed ? Icons.error_outline : Icons.info_outline,
                          color: fg,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DefaultTextStyle(
                            style: TextStyle(
                              color: fg,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            child: snackBar.content,
                          ),
                        ),
                        if (snackBar.action != null) ...[
                          const SizedBox(width: 8),
                          snackBar.action!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeMessageEntry = entry;
    overlay.insert(entry);

    Future.delayed(snackBar.duration, () {
      if (_activeMessageEntry == entry && entry.mounted) {
        entry.remove();
        _activeMessageEntry = null;
      }
    });
  }

  static void hideSnackBar(BuildContext context) {
    final entry = _activeMessageEntry;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
    _activeMessageEntry = null;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryGold,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        secondary: primaryGold,
        surface: surfaceBlack,
        error: errorRed,
        onPrimary: deepBlack,
        onSecondary: deepBlack,
        onSurface: textWhite,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: textWhite,
          displayColor: primaryGold,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
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
      // Removed cardTheme to avoid version conflict,
      // we will handle card styling inside the widgets themselves for stability.
    );
  }
}
