import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_colors.dart';
import '../../core/app_notice.dart';
import '../../core/app_text_styles.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'map_kit.dart';
import 'place_ticket.dart';

/// 沒有進行中的劇本時的地圖：直接抓我現在的位置，有目的地（例如小幫手推薦的地點）就一起標出來，
/// 下面可以選交通方式，選了就用後端的路線規劃畫出從我的位置到目的地的路線。
/// 右上的工具列跟劇本地圖一樣：找附近「吃的」「景點」、定位；點地點開卡片，按「前往」就換成那個目的地
class FreeMap extends StatefulWidget {
  const FreeMap({
    super.key,
    this.destination,
    this.onClose,
    this.onDestination,
  });

  /// 一開始要去的地點；之後在地圖上換目的地、按掉，都是這張地圖自己記
  final PlacePoint? destination;

  /// 按掉目的地（卡片右上的 ✕）：外面把記住的目的地清掉，這張地圖就只剩我的位置
  final VoidCallback? onClose;

  /// 從附近的地點按了「前往」：外面記住這個目的地（切換分頁回來還在）
  final ValueChanged<PlacePoint>? onDestination;

  @override
  State<FreeMap> createState() => _FreeMapState();
}

class _FreeMapState extends State<FreeMap> {
  /// 附近的兩種：「吃的」查飲食、「景點」查其他地點（後端 /api/Map/Nearby 的 category），跟劇本地圖一樣
  static const _foodKind = '飲食';
  static const _photoKind = '其他';

  /// 右上工具列每一格的寬度；地點卡片要讓出這麼寬，才不會蓋住工具列
  static const _toolbarWidth = 64.0;

  static const _distance = Distance();

  final MapController _controller = MapController();
  LatLng? _me;

  /// 要去的地點：一開始是外面帶進來的，從附近的地點按「前往」會換掉，按 ✕ 拿掉
  PlacePoint? _dest;

  // 附近「吃的」「景點」：按了才用我現在的位置向後端查（不會自動一直查），再按一次收起來
  List<NearbyPlace> _nearby = [];
  final Set<String> _nearbyKinds = {};
  bool _nearbyLoading = false;

  /// 連按好幾次時只採用最後一次查回來的
  int _nearbySeq = 0;

  /// 地圖上打開卡片的地點
  NearbyPlace? _selected;

  /// 我面向的方向（度，0 = 北）。GPS 要在移動中才有，不動時不顯示
  double? _heading;
  StreamSubscription<Position>? _positionSub;
  bool _locating = true;
  bool _planning = false;

  String _mode = '步行';
  Map<String, TransportAvailability> _availability = {};
  RouteOption? _option;

  @override
  void initState() {
    super.initState();
    _dest = widget.destination;
    _locate();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  /// 持續追蹤位置和面向的方向（每動 3 公尺更新），只更新藍點，不會重新規劃路線
  void _watchPosition() {
    if (_positionSub != null) return;
    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen((Position pos) {
        if (!mounted) return;
        setState(() {
          _me = LatLng(pos.latitude, pos.longitude);
          // heading 是 -1 或 0 又幾乎沒在動：代表不知道方向
          _heading = pos.heading >= 0 && pos.speed > 0.5 ? pos.heading : _heading;
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _locate() async {
    setState(() => _locating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('請開啟手機的位置服務');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('需要位置權限才能顯示你的位置');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _me = LatLng(position.latitude, position.longitude);
        if (position.heading >= 0 && position.speed > 0.5) {
          _heading = position.heading;
        }
      });
      _watchPosition();
      _fit();
      // 附近的地點有按著的話，用新的位置重新查
      if (_nearbyKinds.isNotEmpty) _loadNearby();

      if (_dest != null) {
        await _checkAvailability();
        await _plan();
      }
    } catch (e) {
      if (mounted) AppNotice.show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  PlacePoint? get _origin {
    final LatLng? me = _me;
    return me == null
        ? null
        : PlacePoint(lat: me.latitude, lng: me.longitude, name: '我的位置');
  }

  /// 這兩點附近有沒有公車、捷運；不能用的交通方式反灰
  Future<void> _checkAvailability() async {
    final PlacePoint? origin = _origin;
    final PlacePoint? dest = _dest;
    if (origin == null || dest == null) return;

    try {
      final result = await Api.instance.post('/api/Route/Availability', [
        origin.toJson(),
        dest.toJson(),
      ]);
      final list = (result as List).cast<Map<String, dynamic>>().map(
        TransportAvailability.fromJson,
      );
      if (!mounted) return;
      setState(() => _availability = {for (final a in list) a.mode: a});
    } catch (_) {
      // 查不到就當全部都能選
    }
  }

  Future<void> _plan() async {
    final PlacePoint? origin = _origin;
    final PlacePoint? dest = _dest;
    if (origin == null || dest == null) return;

    setState(() => _planning = true);

    try {
      final result = await Api.instance.post('/api/Route/Plan', {
        'start': origin.toJson(),
        'points': [dest.toJson()],
        'transportation': [_mode],
        'include_return': false,
      });
      final RoutePlan plan = RoutePlan.fromJson(result as Map<String, dynamic>);
      final List<RouteOption> options = plan.legs.isEmpty
          ? const []
          : plan.legs.first.options;

      if (!mounted) return;

      setState(() {
        _option =
            options.where((o) => o.mode == _mode).firstOrNull ??
            options.firstOrNull;
      });

      if (_option == null) AppNotice.show('找不到這個交通方式的路線');
    } catch (e) {
      if (mounted) {
        setState(() => _option = null);
        AppNotice.show(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  void _fit() {
    final LatLng? me = _me;
    final LatLng? to = _dest?.latLng;

    if (me == null) return;

    if (to == null) {
      _controller.move(me, 16);
      return;
    }

    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [me, to],
        padding: const EdgeInsets.fromLTRB(60, 60, 60, 220),
        maxZoom: 17,
      ),
    );
  }

  List<Polyline> _lines() {
    final RouteOption? option = _option;
    final LatLng? me = _me;
    final PlacePoint? dest = _dest;

    if (option != null) {
      return [
        for (final RouteSegment seg in option.segments)
          if (seg.points.length >= 2)
            Polyline(
              points: seg.points,
              color: seg.mode == '捷運'
                  ? seg.color
                  : modeStyle(seg.mode, lineColor: seg.color).color,
              strokeWidth: modeStyle(seg.mode, lineColor: seg.color).width,
              pattern: modeStyle(seg.mode, lineColor: seg.color).pattern,
              borderStrokeWidth: routeCasingWidth,
              borderColor: Colors.white,
            ),
      ];
    }

    // 還沒有規劃出路線：先拉一條直線
    if (me != null && dest != null) {
      return [
        Polyline(
          points: [me, dest.latLng],
          strokeWidth: 5,
          color: AppColors.primaryAccent,
          borderStrokeWidth: routeCasingWidth,
          borderColor: Colors.white,
        ),
      ];
    }

    return const [];
  }

  void _toggleNearby(String kind) {
    if (_nearbyKinds.contains(kind)) {
      setState(() {
        _nearbyKinds.remove(kind);
        _nearby = _nearby
            .where(
              (p) => _nearbyKinds.contains(p.isFood ? _foodKind : _photoKind),
            )
            .toList();
        if (_selected != null &&
            !_nearby.any((p) => p.key == _selected!.key)) {
          _selected = null;
        }
        if (_nearbyKinds.isEmpty) {
          _nearbySeq++; // 還在查的那一次不要了
          _nearbyLoading = false;
        }
      });
      return;
    }
    setState(() => _nearbyKinds.add(kind));
    _loadNearby();
  }

  /// 附近的地點（GET /api/Map/Nearby，不用劇本）：帶我現在的位置去查按著的種類，後端由近到遠回傳
  Future<void> _loadNearby() async {
    if (_nearbyKinds.isEmpty) return;
    final LatLng? here = _me;
    if (here == null) {
      setState(() => _nearbyKinds.clear());
      AppNotice.show('還不知道你在哪裡，先按右上的「定位」');
      return;
    }
    final int seq = ++_nearbySeq;
    setState(() => _nearbyLoading = true);
    try {
      final result =
          await Api.instance.get('/api/Map/Nearby', {
                'lat': here.latitude,
                'lng': here.longitude,
                'radius_m': 1000,
                'limit': 50,
                // 兩種都按著就不帶，後端兩種都回
                if (_nearbyKinds.length == 1) 'category': _nearbyKinds.first,
              })
              as List;
      final List<NearbyPlace> places = result
          .cast<Map<String, dynamic>>()
          .map(NearbyPlace.fromJson)
          .where((p) => p.point != null)
          .toList();
      if (!mounted || seq != _nearbySeq) return;
      setState(() {
        _nearby = places;
        if (_selected != null && !places.any((p) => p.key == _selected!.key)) {
          _selected = null;
        }
      });
      if (places.isEmpty) AppNotice.show('附近 1 公里內沒有找到');
    } catch (_) {
      if (mounted && seq == _nearbySeq) AppNotice.show('附近地點查詢失敗，請稍後再試');
    } finally {
      if (mounted && seq == _nearbySeq) setState(() => _nearbyLoading = false);
    }
  }

  /// 點地圖上的地點：打開它的卡片，再點一次關掉
  void _showPlace(NearbyPlace place) {
    final bool open = _selected?.key != place.key;
    setState(() => _selected = open ? place : null);
    if (open) {
      try {
        _controller.move(
          place.point!,
          math.max(_controller.camera.zoom, 16),
        );
      } catch (_) {}
    }
  }

  /// 卡片上的「前往」：把這個地點當成目的地，規劃我的位置過去的路線
  Future<void> _goTo(NearbyPlace place) async {
    final LatLng? point = place.point;
    if (point == null) return;
    final PlacePoint dest = PlacePoint(
      lat: point.latitude,
      lng: point.longitude,
      name: place.name,
    );
    setState(() {
      _dest = dest;
      _option = null;
      _availability = {};
      _selected = null;
    });
    widget.onDestination?.call(dest);
    _fit();
    if (_me == null) return;
    await _checkAvailability();
    await _plan();
  }

  /// 按掉目的地：路線拿掉，只剩我的位置
  void _dropDestination() {
    setState(() {
      _dest = null;
      _option = null;
      _availability = {};
    });
    widget.onClose?.call();
  }

  /// 卡片上的小字：離我多遠、有沒有營業
  String? _placeNote(NearbyPlace place) {
    final LatLng? me = _me;
    final int? meters = me == null || place.point == null
        ? null
        : _distance(me, place.point!).round();
    final String? distance = meters == null
        ? null
        : '離你 ${meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1)} km'}';
    final String? status = switch (place.isOpenNow) {
      true => '營業中',
      false => '休息中',
      null => null,
    };
    final String note = [?distance, ?status].join('・');
    return note.isEmpty ? null : note;
  }

  /// 附近地點的標記：飲食是金色刀叉、其他是綠色相機，選中的放大加深色框（跟劇本地圖一樣）
  Marker _nearbyMarker(NearbyPlace p) {
    final bool selected = _selected?.key == p.key;
    final double size = selected ? 44.0 : 36.0;
    return Marker(
      point: p.point!,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => _showPlace(p),
        child: Tooltip(
          message: p.name,
          child: Container(
            decoration: BoxDecoration(
              color: p.isFood ? Pal.gold : Pal.moss,
              borderRadius: BorderRadius.circular(size * 0.28),
              border: Border.all(
                color: selected ? Pal.ink : Colors.white,
                width: selected ? 2.5 : 2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 3),
              ],
            ),
            child: Icon(
              p.isFood ? Icons.restaurant : Icons.local_see,
              size: size * 0.58,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 地圖右上：一條直排的工具列（找附近「吃的」「景點」、定位），長得跟劇本地圖的一樣。
  /// 按著的那一格整格填色，查詢中、定位中轉圈
  Widget _mapControls() {
    const Color panelColor = Color(0xF2EFE5CB);
    const double cellHeight = 58.0;

    Widget cell({
      required String tooltip,
      required VoidCallback? onTap,
      required IconData icon,
      required Color color,
      required String label,
      required bool on,
      required bool busy,
      required Color fill,
    }) => Tooltip(
      message: tooltip,
      child: Material(
        color: on ? fill : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _toolbarWidth,
            height: cellHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, size: 26, color: on ? Colors.white : color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: MapText.caption,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: on ? Colors.white : Pal.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget nearbyCell(
      String kind,
      String label,
      String tooltip,
      IconData icon,
      Color color,
    ) {
      final bool on = _nearbyKinds.contains(kind);
      return cell(
        tooltip: on ? '再按一次收起來' : tooltip,
        onTap: () => _toggleNearby(kind),
        icon: icon,
        color: color,
        label: label,
        on: on,
        busy: on && _nearbyLoading,
        fill: color,
      );
    }

    final Widget divider = Container(
      width: _toolbarWidth,
      height: 1,
      color: PlaceTicket.frame.withValues(alpha: 0.35),
    );

    return Material(
      color: panelColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: PlaceTicket.frame, width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          nearbyCell(_foodKind, '吃的', '找附近吃的', Icons.restaurant, Pal.gold),
          divider,
          nearbyCell(_photoKind, '景點', '找附近景點地標', Icons.photo_camera, Pal.moss),
          divider,
          cell(
            tooltip: '定位',
            onTap: _locating ? null : _locate,
            icon: _me != null ? Icons.my_location : Icons.location_disabled,
            color: Pal.ink,
            label: '定位',
            on: _locating,
            busy: _locating,
            fill: Pal.cinnabar,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? me = _me;
    final PlacePoint? dest = _dest;
    final LatLng center = me ?? dest?.latLng ?? const LatLng(23.9739, 120.9820);
    final RouteOption? option = _option;
    final NearbyPlace? selected = _selected;
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            interactionOptions: mapInteraction,
            // 點地圖空白的地方把地點卡片關掉
            onTap: (_, _) {
              if (_selected != null) setState(() => _selected = null);
            },
          ),
          children: [
            treasureTiles(),
            PolylineLayer(polylines: _lines()),
            MarkerLayer(markers: [for (final p in _nearby) _nearbyMarker(p)]),
            MarkerLayer(
              markers: [
                if (dest != null)
                  Marker(
                    point: dest.latLng,
                    width: 160,
                    height: 72,
                    alignment: Alignment.topCenter,
                    // 地圖轉了，目的地的圖釘和名字還是正的
                    rotate: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.place,
                          size: 36,
                          color: AppColors.primaryAccent,
                        ),
                        // 名字加底色和框（跟景點印章的名字一樣），不會跟底圖的路名疊在一起看不清楚
                        if ((dest.name ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xF2FBF3DF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Pal.ink, width: 1.2),
                            ),
                            child: Text(
                              dest.name!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: MapText.caption,
                                fontWeight: FontWeight.bold,
                                color: Pal.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (me != null && _heading != null)
                  headingMarker(me, _heading!),
                if (me != null)
                  Marker(
                    point: me,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F80ED),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x55000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // 地圖轉過才出現，點一下轉回正北；放在右邊工具列下面
            NorthButton(
              controller: _controller,
              margin: const EdgeInsets.only(
                top: 12 + 58.0 * 3 + 2 + 10,
                right: 12 + (_toolbarWidth + 3 - 40) / 2,
              ),
            ),
            osmAttribution(),
          ],
        ),
        Positioned(top: 12, right: 12, child: _mapControls()),
        if (selected != null)
          Positioned(
            left: 12,
            // 卡片在上方，右邊讓出工具列（寬度 + 邊框 + 間距），兩個並排不重疊
            right: 12 + _toolbarWidth + 3 + 8,
            top: 12,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: PlaceTicket(
                  place: selected,
                  note: _placeNote(selected),
                  compact: !wide,
                  onClose: () => setState(() => _selected = null),
                  onGo: selected.point == null ? null : () => _goTo(selected),
                ),
              ),
            ),
          ),
        if (dest != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 96,
            child: Material(
              color: AppColors.paper,
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _planning
                                ? '路線規劃中…'
                                : (option == null
                                      ? '選擇交通方式'
                                      : '${option.mode}・約 ${option.minutes.round()} 分鐘・${option.distanceKm.toStringAsFixed(1)} 公里'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmallBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // 不去了：把這個目的地拿掉（切換頁面回來也不會再出現）
                        InkWell(
                            onTap: _dropDestination,
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: AppColors.softBrown,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (option != null && option.summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          option.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.softBrown,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final String mode in allModes)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ModeChip(
                                mode: mode,
                                selected: _mode == mode,
                                enabled:
                                    !_planning &&
                                    _me != null &&
                                    _availability[mode]?.enabled != false,
                                onTap: () {
                                  setState(() => _mode = mode);
                                  _plan();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 交通方式按鈕：選中是紅色實心、沒選是羊皮紙底加咖啡色框線，附近沒有的反灰
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected
        ? Colors.white
        : (enabled ? AppColors.textPrimary : AppColors.mutedText);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (enabled ? AppColors.card : AppColors.warmPaper),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.postcardLine,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(modeStyle(mode).icon, size: 18, color: fg),
            const SizedBox(width: 5),
            Text(mode, style: AppTextStyles.captionBold.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
