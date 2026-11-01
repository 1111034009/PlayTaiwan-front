import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_notice.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'map_kit.dart';

/// 沒有進行中的劇本時的地圖：直接抓我現在的位置，有目的地（例如小幫手推薦的地點）就一起標出來，
/// 下面可以選交通方式，選了就用後端的路線規劃畫出從我的位置到目的地的路線
class FreeMap extends StatefulWidget {
  const FreeMap({super.key, this.destination});

  final PlacePoint? destination;

  @override
  State<FreeMap> createState() => _FreeMapState();
}

class _FreeMapState extends State<FreeMap> {
  final MapController _controller = MapController();
  LatLng? _me;
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

      setState(() => _me = LatLng(position.latitude, position.longitude));
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
          color: const Color(0xFFB5493A),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.place,
                          size: 36,
                          color: Color(0xFFB5493A),
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
            osmAttribution(),
          ],
        ),
        Positioned(
          right: 14,
          bottom: 210,
          child: FloatingActionButton.small(
            heroTag: null,
            onPressed: _locating ? null : _locate,
            child: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
              color: const Color(0xFFF3E4C1),
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _planning
                          ? '路線規劃中…'
                          : (option == null
                                ? '選擇交通方式'
                                : '${option.mode}・約 ${option.minutes.round()} 分鐘・${option.distanceKm.toStringAsFixed(1)} 公里'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF40342D),
                      ),
                    ),
                    if (option != null && option.summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          option.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B5B4D),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final String mode in allModes)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                avatar: Icon(modeStyle(mode).icon, size: 16),
                                label: Text(mode),
                                selected: _mode == mode,
                                onSelected:
                                    _planning ||
                                        _me == null ||
                                        _availability[mode]?.enabled == false
                                    ? null
                                    : (_) {
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
