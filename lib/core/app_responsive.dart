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

/// 一般（可捲動 / 列表）頁面的共用外框。
/// - 沒給 [maxWidth]（商家頁）：手機（寬 ≤ 480）照原樣滿版；平板把整頁內容等比放大
///   （以 400 寬排版、放大到螢幕寬，最寬 800），字和按鈕跟著變大，不會一小塊擠在中間。
/// - 有給 [maxWidth]（過往頁，裡面自己有縮放）：內容置中，最寬 [maxWidth]，不再放大。
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  static const double _baseWidth = 400;
  static const double _scaleFrom = 480;
  static const double _scaleMaxWidth = 800;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final bool bounded = constraints.hasBoundedHeight;

        if (maxWidth != null || w <= _scaleFrom) {
          return Center(
            child: SizedBox(
              width: math.min(w, maxWidth ?? AppResponsive.contentMaxWidth),
              height: bounded ? constraints.maxHeight : null,
              child: child,
            ),
          );
        }

        // 同時看高度：手機橫放時高度不夠，不放大（至少 1 倍）
        final double s = math.max(
          1.0,
          math.min(
            math.min(w, _scaleMaxWidth) / _baseWidth,
            bounded ? constraints.maxHeight / 620 : double.infinity,
          ),
        );
        final double fw = _baseWidth * s;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: fw,
            height: bounded ? constraints.maxHeight : null,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _baseWidth,
                height: bounded ? constraints.maxHeight / s : null,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 固定畫布（例如 360x640）的縮放：手機、直放平板照原本「整張塞進螢幕」；
/// 橫放的平板改成以寬度為準放大（最寬 640），不夠高就上下捲動
double canvasScale(double w, double h, double dw, double dh) {
  final double contain = math.min(w / dw, h / dh);
  if (math.min(w, h) >= 500 && w > h) {
    return math.max(contain, math.min(w, 640) / dw);
  }
  return contain;
}

/// 取代登入／註冊頁的 FittedBox(contain)：用 [canvasScale] 決定大小。
/// 外層的高度請用 [canvasHeight]，畫面比螢幕高時才捲得動
class CanvasFit extends StatelessWidget {
  const CanvasFit({
    super.key,
    required this.child,
    this.designWidth = 360,
    this.designHeight = 640,
  });

  final Widget child;
  final double designWidth;
  final double designHeight;

  /// 登入／註冊：一律整張塞進螢幕（不放大超過、也不用上下滑）
  static double canvasHeight(double w, double h, double dw, double dh) => h;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double s = math.min(
          c.maxWidth / designWidth,
          c.maxHeight / designHeight,
        );
        return SizedBox(
          width: designWidth * s,
          height: designHeight * s,
          child: FittedBox(fit: BoxFit.contain, child: child),
        );
      },
    );
  }
}

/// 整張固定畫布的頁面（商家首頁）：自動縮放並可上下捲動
class CanvasScaler extends StatelessWidget {
  const CanvasScaler({
    super.key,
    required this.designWidth,
    required this.designHeight,
    required this.child,
  });

  final double designWidth;
  final double designHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double s = canvasScale(
          c.maxWidth,
          c.maxHeight,
          designWidth,
          designHeight,
        );
        return SingleChildScrollView(
          child: SizedBox(
            width: c.maxWidth,
            height: math.max(c.maxHeight, designHeight * s),
            child: Center(
              child: SizedBox(
                width: designWidth * s,
                height: designHeight * s,
                child: FittedBox(fit: BoxFit.contain, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// SafeArea + ContentFrame：平板上內容跟著放大（見 [ContentFrame]）。
/// 當成 SafeArea 直接替換即可
class SafeFrame extends StatelessWidget {
  const SafeFrame({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.maxWidth,
  });

  final Widget child;
  final bool top;
  final bool bottom;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      child: ContentFrame(maxWidth: maxWidth, child: child),
    );
  }
}

/// 平板（最短邊 ≥ 600）上把整個彈窗放大（最多 1.6 倍），手機照原樣。
/// 當成 Dialog 直接替換即可（參數相同）
class ScaledDialog extends StatelessWidget {
  const ScaledDialog({
    super.key,
    required this.child,
    this.backgroundColor,
    this.elevation,
    this.surfaceTintColor,
    this.shape,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
  });

  final Widget child;
  final Color? backgroundColor;
  final double? elevation;
  final Color? surfaceTintColor;
  final ShapeBorder? shape;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double shortest = mq.size.shortestSide;
    final double s = shortest >= 600
        ? (shortest / 420).clamp(1.0, 1.6).toDouble()
        : 1.0;

    final Dialog dialog = Dialog(
      backgroundColor: backgroundColor,
      elevation: elevation,
      surfaceTintColor: surfaceTintColor,
      shape: shape,
      insetPadding: insetPadding,
      child: child,
    );
    if (s == 1.0) return dialog;

    // 在「縮小 s 倍的假螢幕」裡排版，再整個放大 s 倍：版面、點擊位置都正確
    return LayoutBuilder(
      builder: (context, c) => Transform.scale(
        scale: s,
        child: OverflowBox(
          minWidth: c.maxWidth / s,
          maxWidth: c.maxWidth / s,
          minHeight: c.maxHeight / s,
          maxHeight: c.maxHeight / s,
          child: MediaQuery(
            data: mq.copyWith(
              size: mq.size / s,
              padding: mq.padding / s,
              viewInsets: mq.viewInsets / s,
              viewPadding: mq.viewPadding / s,
            ),
            child: dialog,
          ),
        ),
      ),
    );
  }
}

/// 在 [ContentFrame] / [SafeFrame] 裡面「可用的版面寬度」：手機是螢幕寬，平板是放大前的 400
/// （要用螢幕寬的比例算寬度時，請用這個，不要用 MediaQuery 的寬）
double frameWidth(BuildContext context) {
  final double w = MediaQuery.sizeOf(context).width;
  return w <= 480 ? w : 400;
}

/// 平板（最短邊 ≥ 600）上，小圖示／頭像放大的倍數
double tabletBoost(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600 ? 1.4 : 1.0;
