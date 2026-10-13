// 跟著使用者的位置走：把位置對到路線上、把走過的部分切掉、判斷有沒有偏離路線。
// 都是純計算（不碰地圖、不連後端）；route_page.dart 負責拿定位、畫線、向後端重新規劃。
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'models.dart';

const _earthRadius = 6371000.0;
const _geo = Distance();

/// 兩點距離（公尺）。把經緯度當成平面算（經度差乘上 cos(緯度)）：幾公里內誤差不到千分之一，
/// 跟 snapToLine 用的是同一種算法，沿線距離加起來才會一致。
double _meters(LatLng a, LatLng b) {
  const k = _earthRadius * math.pi / 180;
  final dx = (b.longitude - a.longitude) * k * math.cos((a.latitudeInRad + b.latitudeInRad) / 2);
  final dy = (b.latitude - a.latitude) * k;
  return math.sqrt(dx * dx + dy * dy);
}

// ─────────────────────────── 位置對到路線上 ───────────────────────────

/// 位置對到一條折線上的結果
class LineSnap {
  const LineSnap({
    required this.point,
    required this.index,
    required this.offMeters,
    required this.alongMeters,
    required this.totalMeters,
  });

  /// 折線上離我最近的那一點
  final LatLng point;

  /// 落在第幾段（points[index] → points[index + 1]）
  final int index;

  /// 我離這條線多遠（公尺）
  final double offMeters;

  /// 從折線起點沿著線走到這一點的距離（公尺）
  final double alongMeters;

  /// 整條折線的長度（公尺）
  final double totalMeters;
}

/// 把位置對到折線上最近的一點（點到線段的垂直投影）。
///
/// 做法：以我的位置為原點，把經緯度換成公尺的平面座標（範圍只有幾公里，當成平面的誤差不到 1 公尺），
/// 對每一段 A→B 算投影比例 t = (AP · AB) / |AB|²，夾在 0～1 之間（超出就取端點），
/// 投影點 C = A + t·AB，我離這一段的距離就是 |PC|；取距離最小的那一段。
///
/// [minAlong]：進度只能在這個距離之後（公尺，從折線起點算）。路線繞回來或跟自己交叉時，
/// 不會被對回前面已經走過的那一段。
LineSnap? snapToLine(List<LatLng> pts, LatLng me, {double minAlong = 0}) {
  if (pts.isEmpty) return null;
  if (pts.length == 1) {
    return LineSnap(point: pts.first, index: 0, offMeters: _meters(me, pts.first), alongMeters: 0, totalMeters: 0);
  }

  // 緯度 1 度約 111 公里；經度 1 度要再乘上 cos(緯度)
  const ky = _earthRadius * math.pi / 180;
  final kx = ky * math.cos(me.latitudeInRad);
  double x(LatLng p) => (p.longitude - me.longitude) * kx;
  double y(LatLng p) => (p.latitude - me.latitude) * ky;

  int? bestIndex;
  var bestT = 0.0, bestOff = double.infinity, bestAlong = 0.0;
  var walked = 0.0;

  for (var i = 0; i + 1 < pts.length; i++) {
    final ax = x(pts[i]), ay = y(pts[i]);
    final dx = x(pts[i + 1]) - ax, dy = y(pts[i + 1]) - ay;
    final len = math.sqrt(dx * dx + dy * dy);

    // 這一段有沒有落在 minAlong 之後；只有後半段在的話，t 不能小於 tMin
    if (walked + len >= minAlong) {
      final tMin = len == 0 ? 0.0 : ((minAlong - walked) / len).clamp(0.0, 1.0);
      final t = len == 0 ? 0.0 : ((-ax * dx - ay * dy) / (len * len)).clamp(tMin, 1.0);
      final cx = ax + dx * t, cy = ay + dy * t;
      final off = math.sqrt(cx * cx + cy * cy);

      if (off < bestOff) {
        bestIndex = i;
        bestT = t;
        bestOff = off;
        bestAlong = walked + len * t;
      }
    }
    walked += len;
  }

  // minAlong 比整條線還長：已經走到底了
  if (bestIndex == null) {
    return LineSnap(
      point: pts.last,
      index: pts.length - 2,
      offMeters: _meters(me, pts.last),
      alongMeters: walked,
      totalMeters: walked,
    );
  }

  final a = pts[bestIndex], b = pts[bestIndex + 1];
  return LineSnap(
    point: LatLng(a.latitude + (b.latitude - a.latitude) * bestT, a.longitude + (b.longitude - a.longitude) * bestT),
    index: bestIndex,
    offMeters: bestOff,
    alongMeters: bestAlong,
    totalMeters: walked,
  );
}

// ─────────────────────────── 在一個路線方案上的進度 ───────────────────────────

/// 我在一個路線方案上的進度。方案由幾小段接起來（例如 步行 → 公車 → 步行）
class RouteProgress {
  const RouteProgress({
    required this.segment,
    required this.snap,
    required this.doneMeters,
    required this.totalMeters,
    required this.remainingMinutes,
  });

  /// 人在第幾小段（option.segments 的索引）
  final int segment;

  /// 在那一小段上的位置
  final LineSnap snap;

  /// 整個方案已經走了多少、總共多長（公尺）
  final double doneMeters;
  final double totalMeters;

  /// 還要多久（分鐘）：這一小段依剩下的比例算，後面的小段全算（含候車）
  final double remainingMinutes;

  LatLng get point => snap.point;
  double get offMeters => snap.offMeters;
  double get remainingMeters => math.max(0, totalMeters - doneMeters);
  double get fraction => totalMeters <= 0 ? 1 : (doneMeters / totalMeters).clamp(0.0, 1.0);
}

double _length(List<LatLng> pts) {
  var m = 0.0;
  for (var i = 1; i < pts.length; i++) {
    m += _meters(pts[i - 1], pts[i]);
  }
  return m;
}

/// 方案的總長度（公尺）
double routeMeters(RouteOption option) => option.segments.fold(0.0, (sum, s) => sum + _length(s.points));

/// 我在這個方案上走到哪裡了：每一小段各自對一次，取離我最近的那一小段。
/// [minDone]：進度只能在這個距離之後（公尺，從方案起點算）。呼叫端傳「上一次的進度 − 30 公尺」，
/// 讓進度只會往前（定位飄動時最多退 30 公尺）。
RouteProgress? locateOnRoute(RouteOption option, LatLng me, {double minDone = 0}) {
  final lengths = [for (final s in option.segments) _length(s.points)];
  final total = lengths.fold(0.0, (a, b) => a + b);

  int? best;
  LineSnap? bestSnap;
  var bestDone = 0.0;
  var offset = 0.0;

  for (var k = 0; k < option.segments.length; k++) {
    final pts = option.segments[k].points;
    if (pts.isNotEmpty && offset + lengths[k] >= minDone) {
      final snap = snapToLine(pts, me, minAlong: minDone - offset);
      if (snap != null && (bestSnap == null || snap.offMeters < bestSnap.offMeters)) {
        best = k;
        bestSnap = snap;
        bestDone = offset + snap.alongMeters;
      }
    }
    offset += lengths[k];
  }
  if (best == null || bestSnap == null) return null;

  // 還要多久：這一小段依剩下的距離比例算；後面的小段全算，搭車的要加候車
  final here = option.segments[best];
  final left = lengths[best] <= 0 ? 0.0 : (1 - bestSnap.alongMeters / lengths[best]).clamp(0.0, 1.0);
  final boarded = bestSnap.alongMeters > 20; // 已經離開上車站，候車時間不用再算
  var minutes = here.minutes * left + (boarded ? 0 : here.waitMinutes);
  for (var k = best + 1; k < option.segments.length; k++) {
    minutes += option.segments[k].minutes + option.segments[k].waitMinutes;
  }

  return RouteProgress(segment: best, snap: bestSnap, doneMeters: bestDone, totalMeters: total, remainingMinutes: minutes);
}

/// 把方案切成「走過的」和「還沒走的」。每一段線保留它原本是哪一小段，畫線時才知道交通方式與顏色。
/// [progress] 是 null（還不知道人在哪）時，全部算還沒走。
({List<(RouteSegment, List<LatLng>)> passed, List<(RouteSegment, List<LatLng>)> ahead}) splitRoute(
    RouteOption option, RouteProgress? progress) {
  final passed = <(RouteSegment, List<LatLng>)>[];
  final ahead = <(RouteSegment, List<LatLng>)>[];

  for (var k = 0; k < option.segments.length; k++) {
    final seg = option.segments[k];
    if (progress == null || k > progress.segment) {
      ahead.add((seg, seg.points));
    } else if (k < progress.segment) {
      passed.add((seg, seg.points));
    } else {
      // 人在這一小段上：從對到的那一點切開
      final cut = progress.snap;
      passed.add((seg, [...seg.points.take(cut.index + 1), cut.point]));
      ahead.add((seg, [cut.point, ...seg.points.skip(cut.index + 1)]));
    }
  }
  return (passed: passed, ahead: ahead);
}

// ─────────────────────────── 偏離路線 ───────────────────────────

/// 離路線多遠算偏離（公尺）。GPS 在市區常飄 10～30 公尺，門檻要比它大；
/// 騎車、開車速度快，兩次定位之間走得遠，門檻放寬一點。
double offRouteThreshold(String mode) => switch (mode) {
      '步行' => 40,
      '腳踏車' => 50,
      _ => 60,
    };

/// 判斷要不要重新規劃路線。
/// - 離路線超過門檻要「連續 [needed] 次」才算偏離：單獨一次多半是定位飄了一下
/// - 重新規劃後 [cooldown] 內不再重算：新路線剛出來時，人可能還在走回路線的路上
/// - 定位誤差比 [maxAccuracy] 大時不判斷：連自己在哪都不確定，不該拿來決定重算
/// - 搭公車、捷運時不判斷：人在車上，本來就不會剛好在畫出來的線上
class OffRouteDetector {
  static const needed = 2;
  static const cooldown = Duration(seconds: 12);
  static const maxAccuracy = 100.0;

  int _strikes = 0;
  DateTime? _lastReroute;

  /// 現在是不是偏離路線
  bool get isOff => _strikes >= needed;

  /// 每次位置更新呼叫一次，回傳 true 表示現在該重新規劃。
  /// [accuracy] 是定位的誤差半徑（公尺），門檻不會比它小。
  bool update({
    required double offMeters,
    required String mode,
    bool onRide = false,
    double accuracy = 0,
    DateTime? now,
  }) {
    if (onRide) {
      _strikes = 0;
      return false;
    }
    if (accuracy > maxAccuracy) return false;

    if (offMeters <= math.max(offRouteThreshold(mode), accuracy)) {
      _strikes = 0;
      return false;
    }

    _strikes++;
    if (_strikes < needed) return false;

    final last = _lastReroute;
    return last == null || (now ?? DateTime.now()).difference(last) >= cooldown;
  }

  /// 已經送出重新規劃
  void rerouted([DateTime? now]) => _lastReroute = now ?? DateTime.now();

  /// 換了一條路線（新的一關、換交通方式、重新規劃完成）：從頭算
  void reset() => _strikes = 0;
}

// ─────────────────────────── 模擬行走 ───────────────────────────

/// 方案上距起點 [meters] 公尺的位置，再往行進方向的右邊偏 [drift] 公尺。
/// 示範模式的模擬行走用：坐在電腦前，也能讓「我的位置」沿著路線走、或故意走偏。
LatLng pointOnRoute(RouteOption option, double meters, {double drift = 0}) {
  final pts = [for (final s in option.segments) ...s.points];
  if (pts.isEmpty) return const LatLng(0, 0);

  var point = pts.last;
  var heading = pts.length >= 2 ? _geo.bearing(pts[pts.length - 2], pts.last) : 0.0;
  var walked = 0.0;

  for (var i = 1; i < pts.length; i++) {
    final len = _meters(pts[i - 1], pts[i]);
    if (len > 0 && walked + len >= meters) {
      final t = ((meters - walked) / len).clamp(0.0, 1.0);
      point = LatLng(
        pts[i - 1].latitude + (pts[i].latitude - pts[i - 1].latitude) * t,
        pts[i - 1].longitude + (pts[i].longitude - pts[i - 1].longitude) * t,
      );
      heading = _geo.bearing(pts[i - 1], pts[i]);
      break;
    }
    walked += len;
  }

  return drift == 0 ? point : _geo.offset(point, drift, heading + 90);
}
