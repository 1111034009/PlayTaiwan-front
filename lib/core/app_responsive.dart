import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  /// 平板（含手機橫放）上，一般內容頁最寬只拉到這個寬度，剩下的留白
  static const double contentMaxWidth = 560;

  /// 固定畫布（360x640）在大螢幕上最多放大幾倍，避免平板上整個爆大
  static const double canvasMaxScale = 1.5;
}

/// 一般（可捲動 / 列表）頁面的共用外框：內容置中，最寬 [maxWidth]。
/// 手機照原樣滿版；平板不會把輸入框、卡片拉到整個螢幕寬。
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 寬度、高度都給「緊」的限制，裡面的 Column / Expanded / ListView 行為跟滿版時一樣
        return Center(
          child: SizedBox(
            width: math.min(constraints.maxWidth, maxWidth),
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
