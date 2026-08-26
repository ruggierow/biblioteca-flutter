import 'package:flutter/material.dart';

const bibPrimary = Color(0xFF2B5FB3);
const bibAccent = Color(0xFF1E8A5F);
const bibDanger = Color(0xFFC0392B);
const bibMuted = Color(0xFF6B7280);
const bibBorder = Color(0xFFE2E6EE);
const bibText = Color(0xFF1F2937);

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: bibPrimary,
    primary: bibPrimary,
    secondary: bibAccent,
    error: bibDanger,
  ),
  useMaterial3: true,
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(
    backgroundColor: bibPrimary,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: bibAccent,
    foregroundColor: Colors.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: bibPrimary, width: 2),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: bibPrimary.withOpacity(0.12),
    labelStyle: const TextStyle(color: bibPrimary, fontWeight: FontWeight.w500),
    side: BorderSide.none,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: bibPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
);
