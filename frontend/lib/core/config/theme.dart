import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary = Color(0xFF2DD4BF);      // Teal — CTA
const kSecondary = Color(0xFFF59E0B);    // Amber — ratings
const kError = Color(0xFFEF4444);        // Red — emergency
const kSurface = Color(0xFF1C2333);      // Card background
const kBackground = Color(0xFF0D1117);   // App background
const kDarkTeal = Color(0xFF1B3C40);     // Brand dark teal (existing)

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: kPrimary,
      secondary: kSecondary,
      error: kError,
      surface: kSurface,
    ),
    scaffoldBackgroundColor: kBackground,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kPrimary.withOpacity(0.2)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: kPrimary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
