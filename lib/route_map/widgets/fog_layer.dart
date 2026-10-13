import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

/// 地圖迷霧（像世紀帝國的戰爭迷霧）：整張地圖蓋上霧，只有探索過的地方露出來，邊緣漸層。
/// 放在 FlutterMap 的 children 裡，疊在底圖與路線上面、景點印章下面。
class FogLayer extends StatelessWidget {
  const FogLayer({super.key, required this.spots, this.paths = const [], this.pathMeters = 130});

  /// 露出來的圓形範圍：中心與半徑（公尺）
  final List<(LatLng center, double meters)> spots;

  /// 露出來的路線（走過的與目前這一關的），兩側各露出 [pathMeters] 公尺
  final List<List<LatLng>> paths;
  final double pathMeters;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(size: camera.size, painter: _FogPainter(camera, spots, paths, pathMeters)),
      ),
    );
  }
}

class _FogPainter extends CustomPainter {
  _FogPainter(this.camera, this.spots, this.paths, this.pathMeters);

  final MapCamera camera;
  final List<(LatLng, double)> spots;
  final List<List<LatLng>> paths;
  final double pathMeters;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 這個縮放層級下，螢幕上一個像素是幾公尺
    final metersPerPixel = 156543.03392 * math.cos(camera.center.latitudeInRad) / math.pow(2, camera.zoom);

    // 座標用圖層自己的（getOffsetFromOrigin）：地圖旋轉由 MobileLayerTransformer 處理。
    // 用螢幕座標（latLngToScreenOffset）會再轉一次，地圖一轉霧就跑掉
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = Pal.fog.withValues(alpha: 0.94));

    // 走過的路線：用模糊的粗線把霧擦掉
    final width = math.max(2 * pathMeters / metersPerPixel, 18.0);
    final corridor = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.3);
    for (final line in paths) {
      if (line.length < 2) continue;
      final path = ui.Path();
      for (final (i, p) in line.indexed) {
        final o = camera.getOffsetFromOrigin(p);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, corridor);
    }

    // 探索過的地點：中間全亮，往外漸漸變成霧
    final hole = Paint()..blendMode = BlendMode.dstOut;
    for (final (center, meters) in spots) {
      final c = camera.getOffsetFromOrigin(center);
      final r = math.max(meters / metersPerPixel, 26.0);
      if (!rect.inflate(r).contains(c)) continue;
      hole.shader = ui.Gradient.radial(
        c,
        r,
        const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
        const [0, 0.55, 1],
      );
      canvas.drawCircle(c, r, hole);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FogPainter old) => true;
}
