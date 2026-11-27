// DalaCarbon AI — түстер мен тақырып (сайттағы және логотиптегі түстер).
import 'package:flutter/material.dart';

class Dc {
  static const ink = Color(0xFF0B1F18); // негізгі мәтін
  static const green = Color(0xFF0F4C3A); // логотиптің жасылы
  static const green2 = Color(0xFF2F7D55);
  static const leaf = Color(0xFF6FBF8A);
  static const gold = Color(0xFFE0A93B); // логотиптің алтын жолағы
  static const goldHi = Color(0xFFF2C46A);
  static const cream = Color(0xFFF4F1EA);
  static const paper = Color(0xFFFBFAF6); // экран фоны
  static const input = Color(0xFFF1EFE8);
  static const line = Color(0xFFE6E2D7);
  static const muted = Color(0xFF6B7A72);
  static const danger = Color(0xFFC2453A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Dc.green,
    primary: Dc.green,
    secondary: Dc.gold,
    surface: Dc.paper,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Dc.paper,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Dc.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Dc.input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: Dc.muted, fontSize: 14),
      prefixIconColor: Dc.muted,
      suffixIconColor: Dc.muted,
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(Dc.gold, 1.6),
      errorBorder: border(Dc.danger),
      focusedErrorBorder: border(Dc.danger, 1.6),
    ),
  );
}
