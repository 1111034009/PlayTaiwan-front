import 'dart:math' as math;

//畫面調整
abstract final class AppResponsive {
  static double scale({
    required double availableWidth,
    required double availableHeight,
    required double designWidth,
    required double designHeight,
    double min = 0.0,
    double max = double.infinity,
  }) {
    final widthScale = availableWidth / designWidth;
    final heightScale = availableHeight / designHeight;

    return math.min(widthScale, heightScale).clamp(min, max).toDouble();
  }
}
