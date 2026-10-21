import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

const _distance = Distance();

/// 舊地圖的泛黃色調（一半原色 + 一半 sepia）
const _sepia = ColorFilter.matrix(<double>[
  0.70,
  0.38,
  0.09,
  0,
  0,
  0.17,
  0.84,
  0.08,
  0,
  0,
  0.14,
  0.27,
  0.57,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

/// 藏寶圖底圖（OpenStreetMap + 泛黃濾鏡）。
/// 濾鏡整個圖層套一次，不要每一塊圖磚各包一層：畫面上幾十塊圖磚就多幾十層合成，地圖開久了手機會發燙
Widget treasureTiles() => ColorFiltered(
  colorFilter: _sepia,
  child: TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'tw.playtaiwan.play_taiwan_demo',
  ),
);

Widget osmAttribution() => const SimpleAttributionWidget(
  source: Text('OpenStreetMap contributors'),
  backgroundColor: Color(0xCCF3E4C1),
);

/// 預設的地圖互動（不允許旋轉，箭頭方向才不會亂掉）
const mapInteraction = InteractionOptions(
  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
);

/// 寬螢幕（電腦、平板橫放）：左邊地圖、右邊面板；窄螢幕（手機）：地圖在上、面板從下方拉起。
class MapWithPanel extends StatefulWidget {
  const MapWithPanel({
    super.key,
    required this.map,
    required this.panel,
    this.floating,
    this.floatingRight = false,
  });

  final Widget map;
  final Widget Function(ScrollController? controller) panel;

  /// 常駐在地圖角落的小東西（地圖上的 NPC），放在不擋畫面的地方：
  /// 寬螢幕在地圖右下角；手機在左下角、貼著面板的上緣跟著移動（右邊是交通方式的按鈕，會擠在一起）。
  /// 面板拉得很高時留在原地讓面板蓋過去
  final Widget? floating;

  /// 手機上也放在右下角（正式 App 的貓本來就在右下）
  final bool floatingRight;

  @override
  State<MapWithPanel> createState() => _MapWithPanelState();
}

class _MapWithPanelState extends State<MapWithPanel> {
  /// 面板現在佔螢幕高度的比例
  final _extent = ValueNotifier(0.42);

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map, panel = widget.panel, floating = widget.floating;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(
                child: floating == null
                    ? map
                    : Stack(
                        children: [
                          Positioned.fill(child: map),
                          // 下面讓出外面導覽列的高度（正式 App 的導覽列浮在頁面上面）
                          Positioned(
                            right: 12,
                            bottom: 30 + MediaQuery.paddingOf(context).bottom,
                            child: floating,
                          ),
                        ],
                      ),
              ),
              Container(
                width: 400,
                decoration: const BoxDecoration(
                  color: Pal.parchment,
                  border: Border(left: BorderSide(color: Pal.ink, width: 3)),
                ),
                // 有底色的 Container 會蓋掉 ListTile 的點擊水波，面板內容要再包一層 Material
                child: Material(
                  type: MaterialType.transparency,
                  child: panel(null),
                ),
              ),
            ],
          );
        }
        final minExtent =
            ((MediaQuery.paddingOf(context).bottom + 72) / c.maxHeight).clamp(
              0.12,
              0.4,
            );
        return Stack(
          children: [
            Positioned.fill(child: map),
            if (floating != null)
              ValueListenableBuilder<double>(
                valueListenable: _extent,
                builder: (context, extent, child) => Positioned(
                  left: widget.floatingRight ? null : 12,
                  right: widget.floatingRight ? 12 : null,
                  bottom: math.min(extent, 0.6) * c.maxHeight + 10,
                  child: child!,
                ),
                child: floating,
              ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                _extent.value = n.extent;
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: minExtent,
                maxChildSize: 0.92,
                builder: (context, controller) => Container(
                  decoration: const BoxDecoration(
                    color: Pal.parchment,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x55000000), blurRadius: 12),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: panel(controller),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 方位角（度，北 = 0、順時針）
double bearing(LatLng a, LatLng b) {
  final lat1 = a.latitudeInRad, lat2 = b.latitudeInRad;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double lineLength(List<LatLng> pts) {
  double m = 0;
  for (var i = 1; i < pts.length; i++) {
    m += _distance.distance(pts[i - 1], pts[i]);
  }
  return m;
}

/// 折線上距起點 target 公尺的位置與行進方向
(LatLng, double) pointAlong(List<LatLng> pts, double target) {
  double walked = 0;
  for (var i = 1; i < pts.length; i++) {
    final seg = _distance.distance(pts[i - 1], pts[i]);
    if (seg > 0 && walked + seg >= target) {
      final t = (target - walked) / seg;
      final p = LatLng(
        pts[i - 1].latitude + (pts[i].latitude - pts[i - 1].latitude) * t,
        pts[i - 1].longitude + (pts[i].longitude - pts[i - 1].longitude) * t,
      );
      return (p, bearing(pts[i - 1], pts[i]));
    }
    walked += seg;
  }
  return (
    pts.last,
    pts.length >= 2 ? bearing(pts[pts.length - 2], pts.last) : 0,
  );
}

/// 沿線等距放方向箭頭。去程：實心箭頭；返程：空心箭頭。
List<Marker> arrowMarkers(
  List<LatLng> pts,
  Color color, {
  bool hollow = false,
  double spacing = 380,
}) {
  if (pts.length < 2) return const [];
  final length = lineLength(pts);
  if (length < 40) return const [];

  final count = (length / spacing).floor().clamp(1, 10);
  return List.generate(count, (i) {
    final (point, deg) = pointAlong(pts, length * (i + 0.5) / count);
    return Marker(
      point: point,
      width: 22,
      height: 22,
      child: IgnorePointer(
        child: ArrowIcon(color: color, hollow: hollow, degrees: deg),
      ),
    );
  });
}

class ArrowIcon extends StatelessWidget {
  const ArrowIcon({
    super.key,
    required this.color,
    required this.degrees,
    this.hollow = false,
    this.size = 20,
  });

  final Color color;
  final double degrees;
  final bool hollow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.navigation,
            size: size,
            color: hollow ? color : Colors.white,
          ),
          Icon(
            Icons.navigation,
            size: size * 0.62,
            color: hollow ? Colors.white : color,
          ),
        ],
      ),
    );
  }
}

/// 交通方式徽章（放在每一段路線中間）：圓形圖示，公車/捷運加上路線名
class ModeBadge extends StatelessWidget {
  const ModeBadge({
    super.key,
    required this.mode,
    required this.color,
    this.label,
    this.faded = false,
  });

  final String mode;
  final Color color;
  final String? label;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final style = modeStyle(mode, lineColor: color);
    return Opacity(
      opacity: faded ? 0.35 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x44000000), blurRadius: 3),
              ],
            ),
            child: Icon(style.icon, size: 15, color: Colors.white),
          ),
          if (label != null && label!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 印章的樣子：一般；glow = 目前要去的景點，發亮；dark = 還沒解鎖的景點，暗的，在迷霧上只看得出位置
enum SealLook { normal, glow, dark }

/// 編號印章（劇本景點、起點、公車起訖站）
class SealMarker extends StatelessWidget {
  const SealMarker({
    super.key,
    required this.text,
    this.label,
    this.color = Pal.cinnabar,
    this.faded = false,
    this.look = SealLook.normal,
  });

  final String text;
  final String? label;
  final Color color;
  final bool faded;
  final SealLook look;

  @override
  Widget build(BuildContext context) {
    final dark = look == SealLook.dark;
    final glow = look == SealLook.glow;
    return Opacity(
      opacity: faded ? 0.4 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF4A3F35) : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: dark ? const Color(0xFF8C7B66) : const Color(0xFFF7E7C4),
                width: 2,
              ),
              boxShadow: [
                if (glow)
                  const BoxShadow(
                    color: Color(0xF2FFD76A),
                    blurRadius: 24,
                    spreadRadius: 9,
                  ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: dark ? const Color(0xFFB9AE98) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          if (label != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: dark ? const Color(0xE62A1E14) : const Color(0xEEF3E4C1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF6B5A47)
                      : (glow ? Pal.cinnabar : Pal.inkSoft),
                  width: glow ? 1.6 : 0.8,
                ),
              ),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? const Color(0xFFCDBF9F) : Pal.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 印章 Marker：圓心對準座標，名稱在下方；給 onTap 的話印章和名稱都可以點
Marker sealMarker(
  LatLng point,
  String text, {
  String? label,
  Color color = Pal.cinnabar,
  bool faded = false,
  SealLook look = SealLook.normal,
  VoidCallback? onTap,
}) => Marker(
  point: point,
  width: 130,
  height: 56,
  alignment: const Alignment(0, 0.5),
  // 地圖旋轉時印章和名稱保持正的
  rotate: true,
  child: GestureDetector(
    onTap: onTap,
    child: SealMarker(
      text: text,
      label: label,
      color: color,
      faded: faded,
      look: look,
    ),
  ),
);

/// 路線中間點（依長度），放交通方式徽章用
LatLng midpoint(List<LatLng> pts) => pointAlong(pts, lineLength(pts) / 2).$1;

/// 鏡頭留白：寬螢幕避開左上角圖例；手機避開下方拉起的面板（約 42% 高），左右留地標名稱的寬度
EdgeInsets mapFitPadding(BuildContext context, {double base = 50}) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= 900)
    return EdgeInsets.fromLTRB(base + 110, base, base, base);
  return EdgeInsets.fromLTRB(
    base * 0.9,
    base + 20,
    base * 0.9,
    size.height * 0.42 + base * 0.6,
  );
}

/// 把地圖鏡頭拉到能看到所有點
void fitTo(
  MapController controller,
  List<LatLng> points, {
  EdgeInsets padding = const EdgeInsets.all(60),
}) {
  if (points.isEmpty) return;
  if (points.length == 1) {
    controller.move(points.first, 16);
    return;
  }
  controller.fitCamera(
    CameraFit.coordinates(coordinates: points, padding: padding, maxZoom: 17),
  );
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Pal.cinnabar));
}
