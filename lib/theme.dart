import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Zubia brand colors — magenta + charcoal
class ZubiaColors {
  static const magenta = Color(0xFFFF00FF);
  static const darkMagenta = Color(0xFFD000D0);
  static const charcoalDark = Color(0xFF121212);
  static const charcoalMid = Color(0xFF1C1C1E);
  static const charcoalLight = Color(0xFF252528);
  static const surfaceCard = Color(0xFF232323);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0x59FFFFFF); // 35% white
  static const glassBorder = Color(0x14FFFFFF); // 8% white
  static const glassHover = Color(0x14FFFFFF);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const magentaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [magenta, darkMagenta],
  );
}

ThemeData zubiaTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: ZubiaColors.charcoalDark,
    colorScheme: const ColorScheme.dark(
      primary: ZubiaColors.magenta,
      secondary: ZubiaColors.darkMagenta,
      surface: ZubiaColors.charcoalMid,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: ZubiaColors.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: ZubiaColors.textPrimary,
      displayColor: ZubiaColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: ZubiaColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ZubiaColors.glassBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZubiaColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZubiaColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ZubiaColors.magenta, width: 1.5),
      ),
      hintStyle: const TextStyle(color: ZubiaColors.textMuted),
      labelStyle: const TextStyle(color: ZubiaColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ZubiaColors.magenta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
