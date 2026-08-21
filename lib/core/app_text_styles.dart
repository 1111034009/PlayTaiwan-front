import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

///字體設定

abstract final class AppTextStyles {
  static const double displaySize = 28;
  static const double titleSize = 21;
  static const double sectionTitleSize = 18;
  static const double bodySize = 16;
  static const double bodySmallSize = 14;
  static const double captionSize = 12;
  static const double buttonSize = 16;
  static const double labelSize = 13;

  static TextStyle kaisei({
    double size = bodySize,
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF301717),
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle get display =>
      kaisei(size: displaySize, weight: FontWeight.w700);

  static TextStyle get title =>
      kaisei(size: titleSize, weight: FontWeight.w700);

  static TextStyle get sectionTitle =>
      kaisei(size: sectionTitleSize, weight: FontWeight.w700);

  static TextStyle get body => kaisei(size: bodySize);

  static TextStyle get bodySmall => kaisei(size: bodySmallSize);

  static TextStyle get caption => kaisei(size: captionSize);

  static TextStyle get button =>
      kaisei(size: buttonSize, weight: FontWeight.w700);

  static TextStyle get label =>
      kaisei(size: labelSize, weight: FontWeight.w700);
}
