import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
List<Map<String, dynamic>> _list(Object? v) => ((v as List?) ?? const []).cast<Map<String, dynamic>>();

/// [[經度, 緯度], ...] → LatLng 清單
List<LatLng> parseLine(Object? v) => ((v as List?) ?? const [])
    .map((p) => LatLng(_d((p as List)[1]), _d(p[0])))
    .toList();

/// "#RRGGBB" → Color
Color hexColor(String? hex, [Color fallback = const Color(0xFF757575)]) {
  if (hex == null || hex.isEmpty) return fallback;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}

class PlacePoint {
  PlacePoint({required this.lat, required this.lng, this.name});
  final double lat;
  final double lng;
  final String? name;

  LatLng get latLng => LatLng(lat, lng);

  factory PlacePoint.fromJson(Map<String, dynamic> j) =>
      PlacePoint(lat: _d(j['lat']), lng: _d(j['lng']), name: j['name'] as String?);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'name': name};
}

// ─────────────────────────── 劇本交通路線 ───────────────────────────

class TransportAvailability {
  TransportAvailability.fromJson(Map<String, dynamic> j)
      : mode = j['mode'] as String,
        enabled = j['enabled'] == true,
        reason = j['reason'] as String? ?? '',
        nearestName = j['nearest_name'] as String?;

  final String mode;
  final bool enabled;
  final String reason;
  final String? nearestName;
}

class RouteStopPoint {
  RouteStopPoint.fromJson(Map<String, dynamic> j)
      : snId = j['sn_id'] as int?,
        order = _i(j['order']),
        name = j['name'] as String? ?? '',
        title = j['title'] as String?,
        codename = j['codename'] as String?,
        isCleared = j['is_cleared'] == true,
        isCurrent = j['is_current'] == true,
        point = LatLng(_d(j['lat']), _d(j['lng']));

  final int? snId;
  final int order;

  /// 後端決定的站名：抵達過是景點真名，還沒抵達是地點代號
  final String name;
  final String? title;

  /// 地點代號：藏寶圖上還沒抵達的景點用代號當地標名稱
  final String? codename;
  final bool isCleared;
  final bool isCurrent;
  final LatLng point;
}

class RouteStory {
  RouteStory.fromJson(Map<String, dynamic> j)
      : storyId = _i(j['story_id']),
        title = j['story_title'] as String? ?? '',
        city = j['city_name'] as String? ?? '',
        district = j['district_name'] as String? ?? '',
        nodeCount = _i(j['node_count']),
        suggestedStart = j['suggested_start'] == null ? null : PlacePoint.fromJson(j['suggested_start'] as Map<String, dynamic>),
        nodes = _list(j['nodes']).map(RouteStopPoint.fromJson).toList();

  final int storyId;
  final String title;
  final String city;
  final String district;

  /// 總關卡數（含還在迷霧中的）
  final int nodeCount;
  final PlacePoint? suggestedStart;

  /// 已解鎖的關卡；還在迷霧中的後端不會給
  final List<RouteStopPoint> nodes;
}

// ─────────────────────────── 藏寶圖（GET /api/Map/{story_id}） ───────────────────────────

/// 藏寶圖上的一關。解鎖、破關都由後端決定：破完這一關（任務全部通過）下一關才會解鎖。
class MapNode {
  MapNode.fromJson(Map<String, dynamic> j)
      : nodeId = _i(j['node_id']),
        order = _i(j['node_order']),
        title = j['location_name'] as String? ?? '',
        codename = j['codename'] as String?,
        placeName = j['place_name'] as String?,
        point = LatLng(_d(j['lat']), _d(j['lng'])),
        unlocked = j['is_unlocked'] == true,
        current = j['is_current'] == true,
        arrived = j['is_arrived'] == true,
        completed = j['is_completed'] == true,
        fogRadius = (j['fog_radius_m'] as num?)?.toDouble(),
        imageUrl = j['image_url'] as String?;

  final int nodeId;
  final int order;

  /// 已解鎖：劇情標題；迷霧中：地點代號（後端已經換好）
  final String title;
  final String? codename;

  /// 景點真名，抵達後才有
  final String? placeName;

  /// 已解鎖：景點的精確位置；迷霧中：迷霧中心（大概位置，真正的點在 [fogRadius] 公尺內）
  final LatLng point;
  final bool unlocked;

  /// 目前這一關（地圖上發亮的那一個）
  final bool current;
  final bool arrived;
  final bool completed;
  final double? fogRadius;

  /// 抵達過：景點照片；還沒抵達（迷霧中的關卡，和已解鎖但還沒到的目前這一關）：迷霧圖。
  /// 真實照片一看就知道答案，後端抵達後才給
  final String? imageUrl;

  /// 後端查不到這個景點的座標時回傳 (0, 0)，這種關卡不畫在地圖上
  bool get hasPoint => point.latitude != 0 || point.longitude != 0;

  /// 地圖與面板上顯示的名稱：抵達後是真名，還沒抵達用代號（沒有代號就用劇情標題）
  String get label {
    if (arrived && (placeName ?? '').isNotEmpty) return placeName!;
    final code = codename?.trim() ?? '';
    return code.isNotEmpty ? code : (title.isNotEmpty ? title : '第 $order 關');
  }
}

class TreasureMapData {
  TreasureMapData.fromJson(Map<String, dynamic> j)
      : nodes = (_list(j['nodes']).map(MapNode.fromJson).toList()..sort((a, b) => a.order.compareTo(b.order))),
        revealRadius = _d(j['reveal_radius_m']) > 0 ? _d(j['reveal_radius_m']) : 300,
        demoMode = j['demo_mode'] == true;

  final List<MapNode> nodes;

  /// 已解鎖的景點周圍迷霧散開的半徑（公尺）
  final double revealRadius;

  /// 後端有沒有開示範模式（可以不到現場、不作答就破關）
  final bool demoMode;
}

class RouteSegment {
  RouteSegment.fromJson(Map<String, dynamic> j)
      : mode = j['mode'] as String? ?? '步行',
        color = hexColor(j['color'] as String?),
        minutes = _d(j['minutes']),
        waitMinutes = _d(j['wait_minutes']),
        distanceKm = _d(j['distance_km']),
        points = parseLine(j['coordinates']),
        routeName = j['route_name'] as String?,
        routeTypeName = j['route_type_name'] as String?,
        headsign = j['headsign'] as String?,
        boardName = j['board_name'] as String?,
        alightName = j['alight_name'] as String?,
        stopCount = _i(j['stop_count']),
        stops = _list(j['stops']).map(PlacePoint.fromJson).toList(),
        instruction = j['instruction'] as String? ?? '';

  final String mode;
  final Color color;
  final double minutes;
  final double waitMinutes;
  final double distanceKm;
  final List<LatLng> points;
  final String? routeName;
  final String? routeTypeName;
  final String? headsign;
  final String? boardName;
  final String? alightName;
  final int stopCount;
  final List<PlacePoint> stops;
  final String instruction;

  bool get isRide => mode == '公車' || mode == '台灣好行' || mode == '捷運';
}

class RouteOption {
  RouteOption.fromJson(Map<String, dynamic> j)
      : mode = j['mode'] as String? ?? '',
        minutes = _d(j['minutes']),
        distanceKm = _d(j['distance_km']),
        summary = j['summary'] as String? ?? '',
        isChosen = j['is_chosen'] == true,
        segments = _list(j['segments']).map(RouteSegment.fromJson).toList();

  final String mode;
  final double minutes;
  final double distanceKm;
  final String summary;
  final bool isChosen;
  final List<RouteSegment> segments;
}

class RouteLeg {
  RouteLeg.fromJson(Map<String, dynamic> j)
      : legOrder = _i(j['leg_order']),
        direction = j['direction'] as String? ?? '去程',
        fromName = j['from_name'] as String? ?? '',
        toName = j['to_name'] as String? ?? '',
        options = _list(j['options']).map(RouteOption.fromJson).toList();

  final int legOrder;
  final String direction;
  final String fromName;
  final String toName;

  /// 所有方案，第一個是後端採用的（最快）
  final List<RouteOption> options;

  bool get isReturn => direction == '返程';
}

class RoutePlan {
  RoutePlan.fromJson(Map<String, dynamic> j)
      : storyTitle = j['story_title'] as String?,
        start = PlacePoint.fromJson(j['start'] as Map<String, dynamic>),
        stops = _list(j['stops']).map(RouteStopPoint.fromJson).toList(),
        legs = _list(j['legs']).map(RouteLeg.fromJson).toList(),
        warnings = ((j['warnings'] as List?) ?? const []).cast<String>();

  final String? storyTitle;
  final PlacePoint start;
  final List<RouteStopPoint> stops;
  final List<RouteLeg> legs;
  final List<String> warnings;
}

class MetroStation {
  MetroStation.fromJson(Map<String, dynamic> j)
      : name = j['station_name'] as String? ?? '',
        point = LatLng(_d(j['lat']), _d(j['lng']));

  final String name;
  final LatLng point;
}

class MetroLine {
  MetroLine.fromJson(Map<String, dynamic> j)
      : systemName = j['system_name'] as String? ?? '',
        lineName = j['line_name'] as String? ?? '',
        color = hexColor(j['line_color'] as String?, const Color(0xFF00897B)),
        stations = _list(j['stations']).map(MetroStation.fromJson).toList(),
        shape = ((j['shape'] as List?) ?? const []).map(parseLine).toList();

  final String systemName;
  final String lineName;
  final Color color;
  final List<MetroStation> stations;
  final List<List<LatLng>> shape;
}

// ─────────────────────────── 周邊好去 ───────────────────────────

class NearbyPlace {
  /// 劇本關卡的卡片：名稱（真名或代號）、照片；[navigable] 是抵達過的景點，才給「前往地址」
  NearbyPlace.node(MapNode node, {required bool navigable})
      : key = 'node-${node.nodeId}',
        category = 'Attraction',
        type = null,
        name = node.label,
        address = null,
        openTime = null,
        distanceM = null,
        isOpenNow = null,
        photoUrls = [if ((node.imageUrl ?? '').isNotEmpty) node.imageUrl!],
        mapsUrl = navigable ? 'https://www.google.com/maps/search/?api=1&query=${node.point.latitude},${node.point.longitude}' : null,
        point = node.point;

  NearbyPlace.fromJson(Map<String, dynamic> j)
      : key = (j['place_uid'] as String?) ?? 'place-${_i(j['place_id'])}',
        distanceM = (j['distance_m'] as num?)?.toInt(),
        isOpenNow = j['is_open_now'] as bool?,
        category = j['category'] as String?,
        type = j['type'] as String?,
        name = j['name'] as String? ?? '',
        address = j['address'] as String?,
        openTime = j['open_time'] as String?,
        photoUrls = ((j['photo_urls'] as List?) ?? const []).cast<String>(),
        mapsUrl = j['maps_deeplink_url'] as String?,
        point = _nearbyPoint(j);

  /// 用餐提醒（GET /api/Map/NearbyFood）回傳的店家，欄位名稱跟周邊好去的不太一樣
  NearbyPlace.food(Map<String, dynamic> j)
      : key = 'food-${j['place_id']}',
        distanceM = (j['distance_m'] as num?)?.toInt(),
        isOpenNow = j['is_open_now'] as bool?,
        category = '飲食',
        type = j['type'] as String?,
        name = j['name'] as String? ?? '',
        address = j['address'] as String?,
        openTime = j['open_time'] as String?,
        photoUrls = [if ((j['image_url'] as String? ?? '').isNotEmpty) j['image_url'] as String],
        mapsUrl = j['maps_deeplink_url'] as String?,
        point = _nearbyPoint(j);

  /// 座標；舊版後端沒有 lat/lng 欄位時，從 Google Maps 連結的 query=緯度,經度 取
  static LatLng? _nearbyPoint(Map<String, dynamic> j) {
    if (j['lat'] != null && j['lng'] != null) return LatLng(_d(j['lat']), _d(j['lng']));
    final m = RegExp(r'query=(-?[\d.]+),(-?[\d.]+)').firstMatch(j['maps_deeplink_url'] as String? ?? '');
    return m == null ? null : LatLng(double.parse(m.group(1)!), double.parse(m.group(2)!));
  }

  /// 地點的識別碼（Neo4j uid，或 place-{p_id}）
  final String key;
  final String? category;
  final String? type;
  final String name;
  final String? address;
  final String? openTime;

  /// 跟使用者目前位置的直線距離（公尺）
  final int? distanceM;

  /// 現在有沒有營業；沒有資料時是 null
  final bool? isOpenNow;
  final List<String> photoUrls;
  final String? mapsUrl;
  final LatLng? point;

  bool get isFood => category == '飲食';

  /// 卡片上的分類標籤：資料庫的 Attraction 顯示成「景點」
  String get categoryLabel => switch (category) {
        null || '' => '其他',
        'Attraction' => '景點',
        final c => c,
      };
}

// ─────────────────────────── 公車 ───────────────────────────

/// 一起玩的隊友最後回報的位置（POST /api/Pair/Story/{story_id}/Location 的 members）
class Teammate {
  Teammate.fromJson(Map<String, dynamic> j)
      : name = j['auth_name'] as String? ?? '',
        isMe = j['is_me'] == true,
        online = j['is_online'] == true,
        point = j['lat'] == null || j['lng'] == null ? null : LatLng(_d(j['lat']), _d(j['lng']));

  final String name;
  final bool isMe;

  /// 最近有回報位置；false 的畫成淡的
  final bool online;

  /// 還沒回報過（或太久沒回報）時是 null，不畫
  final LatLng? point;
}
