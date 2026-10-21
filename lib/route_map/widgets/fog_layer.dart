import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
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
    // RepaintBoundary：地圖上其他東西重畫時，迷霧沒變就直接用上次畫好的
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(size: camera.size, painter: _FogPainter(camera, spots, paths, pathMeters)),
        ),
      ),
    );
  }
}

/// 路線邊緣漸層分幾層畫（見 _FogPainter.paint）
const int _featherSteps = 8;

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

    // 走過的路線：用粗線把霧擦掉，邊緣漸層。
    // 不用 MaskFilter.blur：路線很粗（兩側各上千公尺），放大地圖時模糊半徑會到上百像素，每次重畫 GPU 都很吃力，手機會發燙。
    // 改成由外往內疊幾條越來越細的線（最外圈全寬、最內圈 7 成寬），第 k 條擦掉剩下的 1/(n-k+1)，
    // 外圈的霧就一層一層變淡（線性漸層），內圈 7 成全亮，看起來跟模糊差不多
    final width = math.max(2 * pathMeters / metersPerPixel, 18.0);
    final corridors = [for (final line in paths) if (line.length >= 2) _toPath(line)];
    for (var k = 1; k <= _featherSteps; k++) {
      final corridor = Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * (1 - 0.3 * (k - 1) / (_featherSteps - 1))
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 1 / (_featherSteps - k + 1));
      for (final path in corridors) {
        canvas.drawPath(path, corridor);
      }
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

  ui.Path _toPath(List<LatLng> line) {
    final path = ui.Path();
    for (final (i, p) in line.indexed) {
      final o = camera.getOffsetFromOrigin(p);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path;
  }

  /// 只有鏡頭動了、或露出來的範圍變了才重畫。地圖每次更新（定位、隊友、面板）都會重建圖層，
  /// 原本一律重畫，等於一直在算整張全螢幕的迷霧
  @override
  bool shouldRepaint(covariant _FogPainter old) =>
      old.camera.center != camera.center ||
      old.camera.zoom != camera.zoom ||
      old.camera.rotation != camera.rotation ||
      old.camera.size != camera.size ||
      old.pathMeters != pathMeters ||
      !listEquals(old.spots, spots) ||
      old.paths.length != paths.length ||
      [for (final (i, line) in paths.indexed) listEquals(old.paths[i], line)].contains(false);
}
