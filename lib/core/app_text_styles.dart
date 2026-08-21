import 'package:flutter/material.dart';

///字體設定
abstract final class AppTextStyles {
  static const double microSize = 10;
  static const double captionSize = 12;
  static const double bodySmallSize = 14;
  static const double bodySize = 16;
  static const double sectionTitleSize = 18;
  static const double titleSize = 21;
  static const double displaySize = 28;

  static const List<double> levels = [
    microSize,
    captionSize,
    bodySmallSize,
    bodySize,
    sectionTitleSize,
    titleSize,
    displaySize,
  ];

  static double normalizeFontSize(double size) {
    if (size <= 10.75) return microSize;
    if (size <= 12.75) return captionSize;
    if (size <= 15.25) return bodySmallSize;
    if (size <= 17.5) return bodySize;
    if (size <= 20.0) return sectionTitleSize;
    if (size <= 23.5) return titleSize;
    return displaySize;
  }

  static TextStyle kaisei({
    double size = bodySize,
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF301717),
  }) {
    return TextStyle(
      fontFamily: 'KaiseiHarunoUmi',
      fontSize: normalizeFontSize(size),
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle get micro => kaisei(size: microSize);

  static TextStyle get caption => kaisei(size: captionSize);

  static TextStyle get bodySmall => kaisei(size: bodySmallSize);

  static TextStyle get body => kaisei(size: bodySize);

  static TextStyle get sectionTitle =>
      kaisei(size: sectionTitleSize, weight: FontWeight.w700);

  static TextStyle get title =>
      kaisei(size: titleSize, weight: FontWeight.w700);

  static TextStyle get button =>
      kaisei(size: bodySize, weight: FontWeight.w700);

  static TextStyle get label =>
      kaisei(size: captionSize, weight: FontWeight.w700);

  static TextStyle get display =>
      kaisei(size: displaySize, weight: FontWeight.w700);
}
