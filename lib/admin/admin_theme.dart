import 'package:flutter/material.dart';

class AdminColors {
  AdminColors._();

  static const canvas = Color(0xFFF7F1E8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFFF9F2);
  static const primary = Color(0xFFA9754F);
  static const primarySoft = Color(0xFFEDE0D3);
  static const secondary = Color(0xFF9C8672);
  static const highlight = Color(0xFF7A9D54);
  static const highlightSoft = Color(0xFFE4EBD8);
  static const danger = Color(0xFFC96A55);
  static const dangerSoft = Color(0xFFF3E1DC);
  static const textMain = Color(0xFF4A3728);
  static const textMuted = Color(0xFF806F61);
  static const border = Color(0xFFE6DCCB);
  static const roleAdmin = Color(0xFF4B3C52);
  static const roleAdminSoft = Color(0xFFEDE3F2);
  static const rolePlayer = Color(0xFF5B8A8A);
  static const rolePlayerSoft = Color(0xFFE1EBEB);
}

class AdminText {
  AdminText._();

  static const String family = 'KaiseiHarunoUmi';
  static const List<String> fallback = ['Yomogi'];

  static const caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AdminColors.textMuted,
  );

  static const bodySmall = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AdminColors.textMain,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AdminColors.textMain,
  );

  static const section = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AdminColors.textMain,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AdminColors.textMain,
  );
}

class AdminR {
  AdminR._();

  static const double desktop = 1100;
  static const double contentMax = 1500;

  static double padding(double w) {
    if (w < 380) return 10;
    if (w < 600) return 14;
    if (w < 700) return 18;
    if (w < desktop) return 22;
    return 28;
  }
}

ThemeData adminTheme(ThemeData base) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: AdminText.family,
      fontFamilyFallback: AdminText.fallback,
      bodyColor: AdminColors.textMain,
      displayColor: AdminColors.textMain,
    ),
    scaffoldBackgroundColor: AdminColors.canvas,
    colorScheme: ColorScheme.fromSeed(seedColor: AdminColors.primary),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AdminColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(AdminColors.border),
      enabledBorder: border(AdminColors.border),
      focusedBorder: border(AdminColors.primary, 1.4),
      hintStyle: AdminText.caption,
      labelStyle: AdminText.caption,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        textStyle: AdminText.bodySmall.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.textMain,
        textStyle: AdminText.bodySmall,
        side: const BorderSide(color: AdminColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.primary,
        textStyle: AdminText.bodySmall,
      ),
    ),
  );
}
