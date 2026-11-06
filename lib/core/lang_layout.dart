// 多語系版面：翻譯比中文長時，畫面怎麼讓步。要調的數字都集中在 [LangLayout]。
//
// 做法：換成外語時，所有 Text（lib/core/i18n.dart 的那個）外面自動包一層 [ShrinkToFit]：
// - 放得下：完全不動。
// - 放不下（單行被截成「…」、超過 maxLines、固定高度的框裝不下、英文單字被拆成兩行）：字先等比縮小，
//   最多縮到 [LangLayout.minTextScale]，還是放不下才出現「…」。
// - 繁體中文不套用，維持原本的設計。
//
// 寫新畫面時：
// - 固定高度、只能一行的地方（按鈕、標籤、下拉選單）：Text 加 maxLines: 1，外語放不下就會縮字。
// - Row 裡的文字：包 Flexible／Expanded。Row 給文字無限寬，縮字救不了，會出現黃黑條警告。
// - 輸入框提示字：用 [FitHint]。
// 檢查方式：flutter test test/layout_audit_test.dart，報告在 build/layout_audit.txt。
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';

import 'app_responsive.dart';
import 'i18n.dart';

enum DeviceKind { phone, tablet, desktop }

abstract final class LangLayout {
  /// 會自動縮字的語言（繁體中文照原本設計，不縮）
  static const Set<String> shrinkLangs = {'en', 'ja', 'ko', 'nan', 'hak'};

  /// 放不下時最多縮到原本字級的幾倍。
  /// 平板、電腦上 App 頁面會整頁放大（ContentFrame、CanvasScaler，1.5～2 倍），排版寬度跟手機一樣，
  /// 所以縮完的字實際上還是比手機大，下限可以比手機低；手機本來就小，不要縮太多
  static const Map<DeviceKind, double> minTextScale = {
    DeviceKind.phone: 0.72,
    DeviceKind.tablet: 0.66,
    DeviceKind.desktop: 0.68,
  };

  /// 電腦：視窗寬度至少這麼寬（管理後台、瀏覽器）
  static const double desktopMinWidth = 1200;

  static DeviceKind deviceOf(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (size.width >= desktopMinWidth) return DeviceKind.desktop;
    if (size.shortestSide >= AppResponsive.tabletShortestSide) return DeviceKind.tablet;
    return DeviceKind.phone;
  }

  static bool get shrinkEnabled => shrinkLangs.contains(AppLang.code);

  static double minScaleOf(BuildContext context) => minTextScale[deviceOf(context)]!;

  /// 外語比中文長（英文大約是中文的 2 倍寬），縮字也放不下時多給幾行
  static const int extraLines = 1;

  /// 標題、店名、站名這類放不下就截成「…」的字：中文照原本行數，外語多 [extraLines] 行。
  /// 用法：Text(title, maxLines: LangLayout.lines(1), overflow: TextOverflow.ellipsis)
  static int lines(int zh) => shrinkEnabled ? zh + extraLines : zh;
}

/// 輸入框的提示字：hintText 是 Flutter 自己畫的，外語放不下只會被截成「…」。
/// 改成 InputDecoration(hint: FitHint('搜尋店名', style: 原本的 hintStyle, textAlign: 輸入框的 textAlign))，
/// 外語時會先縮字。用 hint 時 InputDecoration 不會幫忙套 hintStyle、textAlign，所以要自己傳；
/// 原本沒有 hintStyle 的，提示字會跟著輸入框的字型，要把輸入框的 style 傳給 [fieldStyle]
class FitHint extends StatelessWidget {
  const FitHint(this.text, {super.key, this.style, this.fieldStyle, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextStyle? fieldStyle;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // 跟 InputDecorator 算 hintText 樣式的方式一樣（Material 3）：
    // bodyLarge → 輸入框的 style → 提示色 → hintStyle
    final TextStyle hintStyle = theme.textTheme.bodyLarge!
        .merge(fieldStyle)
        .merge(TextStyle(color: theme.colorScheme.onSurfaceVariant))
        .merge(theme.inputDecorationTheme.hintStyle)
        .merge(style);
    return Text(text, style: hintStyle, textAlign: textAlign, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// 子元件（一段文字）放不下時等比縮小，最多縮到 [minScale]
class ShrinkToFit extends SingleChildRenderObjectWidget {
  const ShrinkToFit({super.key, required this.minScale, super.child});

  final double minScale;

  @override
  RenderShrinkToFit createRenderObject(BuildContext context) => RenderShrinkToFit(minScale);

  @override
  void updateRenderObject(BuildContext context, RenderShrinkToFit renderObject) {
    renderObject.minScale = minScale;
  }
}

class RenderShrinkToFit extends RenderProxyBox {
  RenderShrinkToFit(this._minScale);

  double get minScale => _minScale;
  double _minScale;
  set minScale(double value) {
    if (value == _minScale) return;
    _minScale = value;
    markNeedsLayout();
  }

  /// 目前的縮放倍數（1 = 沒縮）
  double get scale => _scale;
  double _scale = 1;

  /// 文字本體：m.Text 會再包 Semantics 之類的單一子元件，一路往下找
  RenderParagraph? _paragraph() {
    RenderObject? node = child;
    while (node != null) {
      if (node is RenderParagraph) return node;
      if (node is RenderObjectWithChildMixin<RenderBox>) {
        node = node.child;
      } else {
        return null;
      }
    }
    return null;
  }

  bool _overflows(BoxConstraints c) {
    final RenderParagraph? p = _paragraph();
    if (p == null) return false;
    if (p.didExceedMaxLines) return true;
    final Size text = p.textSize;
    return text.width > p.size.width + 0.5 ||
        (c.hasBoundedHeight && text.height > p.size.height + 0.5) ||
        // 最長的單字比寬度還寬：英文單字會從中間被拆成兩行（Collec／tion），也要縮
        child!.getMinIntrinsicWidth(double.infinity) > p.size.width + 0.5;
  }

  void _layoutAt(double s) {
    child!.layout(
      BoxConstraints(
        minWidth: constraints.minWidth / s,
        maxWidth: constraints.maxWidth / s,
        minHeight: constraints.minHeight / s,
        maxHeight: constraints.maxHeight / s,
      ),
      parentUsesSize: true,
    );
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      _scale = 1;
      size = constraints.smallest;
      return;
    }
    _scale = 1;
    child.layout(constraints, parentUsesSize: true);
    if (_minScale < 1 && _overflows(constraints)) {
      // 二分法找「放得下的最大倍數」；最小倍數也放不下就用最小倍數（文字自己會出現「…」）
      double lo = _minScale, hi = 1;
      _layoutAt(lo);
      if (!_overflows(constraints)) {
        for (var i = 0; i < 6; i++) {
          final double mid = (lo + hi) / 2;
          _layoutAt(mid);
          if (_overflows(constraints)) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
      }
      _scale = lo;
      _layoutAt(_scale);
    }
    size = constraints.constrain(child.size * _scale);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final double? d = child?.getDistanceToActualBaseline(baseline);
    return d == null ? null : d * _scale;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      child == null ? constraints.smallest : constraints.constrain(child!.getDryLayout(constraints));

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scale == 1) {
      context.paintChild(child!, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, offset) => context.paintChild(child!, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, position) => child!.hitTest(result, position: position),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('scale', _scale));
    properties.add(DoubleProperty('minScale', _minScale));
  }
}

/// 外語時把一段文字包進 [ShrinkToFit]（i18n.dart 的 Text 用）
Widget shrinkWhenNeeded(BuildContext context, Widget text) {
  if (!LangLayout.shrinkEnabled) return text;
  return ShrinkToFit(minScale: math.min(1, LangLayout.minScaleOf(context)), child: text);
}
