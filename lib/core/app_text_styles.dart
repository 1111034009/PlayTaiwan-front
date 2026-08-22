import 'package:flutter/material.dart';
import 'app_colors.dart';

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

  static FontWeight normalizeWeight(FontWeight weight) {
    if (weight == FontWeight.w400) return FontWeight.w400;
    if (weight == FontWeight.w500) return FontWeight.w500;
    return FontWeight.w700;
  }

  static TextStyle fromSize({
    double size = bodySize,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: 'KaiseiHarunoUmi',
      fontSize: size,
      fontWeight: normalizeWeight(weight),
      color: color,
    );
  }

  static TextStyle get micro => fromSize(size: microSize);

  static TextStyle get caption => fromSize(size: captionSize);

  static TextStyle get bodySmall => fromSize(size: bodySmallSize);

  static TextStyle get body => fromSize(size: bodySize);

  static TextStyle get sectionTitle =>
      fromSize(size: sectionTitleSize, weight: FontWeight.w700);

  static TextStyle get title =>
      fromSize(size: titleSize, weight: FontWeight.w700);

  static TextStyle get button =>
      fromSize(size: bodySize, weight: FontWeight.w700);

  static TextStyle get label =>
      fromSize(size: captionSize, weight: FontWeight.w700);

  static TextStyle get display =>
      fromSize(size: displaySize, weight: FontWeight.w700);

  static TextStyle get microBold =>
      fromSize(size: microSize, weight: FontWeight.w700);

  static TextStyle get microTightBold =>
      fromSize(size: 9.8, weight: FontWeight.w700);

  static TextStyle get microDenseBold =>
      fromSize(size: 10.5, weight: FontWeight.w700);

  static TextStyle get microSmall => fromSize(size: 11);

  static TextStyle get microLabel =>
      fromSize(size: 11, weight: FontWeight.w700);

  static TextStyle get microLabelWide =>
      fromSize(size: 11.5, weight: FontWeight.w700);

  static TextStyle get labelWide =>
      fromSize(size: 12.5, weight: FontWeight.w700);

  static TextStyle get captionSmall => fromSize(size: 13);

  static TextStyle get captionBold =>
      fromSize(size: 13, weight: FontWeight.w700);

  static TextStyle get captionWide =>
      fromSize(size: 13.5, weight: FontWeight.w700);

  static TextStyle get bodySmallMedium =>
      fromSize(size: bodySmallSize, weight: FontWeight.w500);

  static TextStyle get bodySmallBold =>
      fromSize(size: bodySmallSize, weight: FontWeight.w700);

  static TextStyle get bodyCompact => fromSize(size: 15);

  static TextStyle get bodyCompactBold =>
      fromSize(size: 15.5, weight: FontWeight.w700);

  static TextStyle get bodyEmphasis =>
      fromSize(size: 15, weight: FontWeight.w700);

  static TextStyle get bodyEmphasisBold =>
      fromSize(size: 15, weight: FontWeight.w700);

  static TextStyle get bodyBold =>
      fromSize(size: bodySize, weight: FontWeight.w700);

  static TextStyle get subtitle =>
      fromSize(size: 17, weight: FontWeight.w700);

  static TextStyle get subtitleMedium =>
      fromSize(size: 17, weight: FontWeight.w700);

  static TextStyle get sectionTitleMedium =>
      fromSize(size: sectionTitleSize, weight: FontWeight.w500);

  static TextStyle get titleMedium =>
      fromSize(size: 19, weight: FontWeight.w700);

  static TextStyle get titleMediumBold =>
      fromSize(size: 19, weight: FontWeight.w700);

  static TextStyle get heading =>
      fromSize(size: 20, weight: FontWeight.w700);

  static TextStyle get titleLarge =>
      fromSize(size: 22, weight: FontWeight.w700);

  static TextStyle get pageTitle =>
      fromSize(size: 23, weight: FontWeight.w700);

  static TextStyle get displayMedium =>
      fromSize(size: 24, weight: FontWeight.w700);

  static TextStyle get displayLarge =>
      fromSize(size: 25, weight: FontWeight.w700);

  static TextStyle get displayLargeWide =>
      fromSize(size: 26, weight: FontWeight.w700);

  static TextStyle get heroTitle =>
      fromSize(size: 27, weight: FontWeight.w700);

  static TextStyle get heroDisplay =>
      fromSize(size: 30, weight: FontWeight.w700);

  static TextStyle get merchantStat =>
      fromSize(size: 39, weight: FontWeight.w700);

  static TextStyle topBarTitle(double scale) =>
      fromSize(size: (14.0 * scale).clamp(10.0, 14.0).toDouble(), weight: FontWeight.w700).copyWith(height: 1.0);

  static TextStyle topBarNumber(double scale) =>
      fromSize(size: (13.0 * scale).clamp(9.0, 13.0).toDouble(), weight: FontWeight.w700).copyWith(height: 1.0);
}
