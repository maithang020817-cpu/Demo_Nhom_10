import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const primary = Color(0xFF8C2F39);
  static const primaryDark = Color(0xFF6B1F28);
  static const peach = Color(0xFFF4DCDD);
  static const peachSoft = Color(0xFFFAEDED);
  static const bg = Color(0xFFFAF5F2);
  static const card = Color(0xFFFFFFFF);
  static const blueSoft = Color(0xFFE9EEF5);
  static const blueText = Color(0xFF3A5273);
  static const text = Color(0xFF2A1D1F);
  static const muted = Color(0xFF86747A);
  static const green = Color(0xFF2E8B57);
  static const greenSoft = Color(0xFFDDF1E5);
  static const red = Color(0xFFC8503F);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.primary,
    primary: C.primary,
    onPrimary: Colors.white,
    surface: C.bg,
    brightness: Brightness.light,
  );
  final base = ThemeData(
      colorScheme: scheme, useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    appBarTheme: const AppBarTheme(
        backgroundColor: C.bg,
        foregroundColor: C.text,
        elevation: 0,
        scrolledUnderElevation: 0),
    cardTheme: CardThemeData(color: C.card),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.primary,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: C.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.primary, width: 1.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.text,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}