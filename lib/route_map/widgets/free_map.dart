import 'dart:async';

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

/// 沒有進行中的劇本時的地圖：直接抓我現在的位置，有目的地（例如小幫手推薦的地點）就一起標出來，
/// 下面可以選交通方式，選了就用後端的路線規劃畫出從我的位置到目的地的路線
class FreeMap extends StatefulWidget {
  const FreeMap({super.key, this.destination, this.onClose});

  final PlacePoint? destination;

  /// 按掉目的地（卡片右上的 ✕）：外面把記住的目的地清掉，這張地圖就只剩我的位置
  final VoidCallback? onClose;

  @override
  State<FreeMap> createState() => _FreeMapState();
}

class _FreeMapState extends State<FreeMap> {
  final MapController _controller = MapController();
  LatLng? _me;

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

      if (widget.destination != null) {
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
    final PlacePoint? dest = widget.destination;
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
    final PlacePoint? dest = widget.destination;
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
    final LatLng? to = widget.destination?.latLng;

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
    final PlacePoint? dest = widget.destination;

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
              borderStrokeWidth: modeStyle(seg.mode).casing ? 2.5 : 0,
              borderColor: Colors.white,
            ),
      ];
    }

    // 還沒有規劃出路線：先拉一條直線
    if (me != null && dest != null) {
      return [
        Polyline(
          points: [me, dest.latLng],
          strokeWidth: 3,
          color: AppColors.primaryAccent,
        ),
      ];
    }

    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? me = _me;
    final PlacePoint? dest = widget.destination;
    final LatLng center = me ?? dest?.latLng ?? const LatLng(23.9739, 120.9820);
    final RouteOption? option = _option;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            interactionOptions: mapInteraction,
          ),
          children: [
            treasureTiles(),
            PolylineLayer(polylines: _lines()),
            MarkerLayer(
              markers: [
                if (dest != null)
                  Marker(
                    point: dest.latLng,
                    width: 120,
                    height: 64,
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
                        if ((dest.name ?? '').isNotEmpty)
                          Text(
                            dest.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF40342D),
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
            // 地圖轉過才出現，點一下轉回正北
            NorthButton(controller: _controller),
            osmAttribution(),
          ],
        ),
        Positioned(
          right: 14,
          bottom: 210,
          child: FloatingActionButton.small(
            heroTag: null,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: _locating ? null : _locate,
            child: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location),
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
                        if (widget.onClose != null)
                          InkWell(
                            onTap: widget.onClose,
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
