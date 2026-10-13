// 跟著位置走的計算（route_follow.dart）：位置對到路線、切掉走過的部分、偏離判斷、模擬行走
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:playtaiwan/route_map/models.dart';
import 'package:playtaiwan/route_map/route_follow.dart';

/// 緯度 1 度的公尺數
const _perDegree = 111194.93;

/// 起點 (24, 120) 往北 north 公尺、往東 east 公尺的點
LatLng at(double north, [double east = 0]) => LatLng(24 + north / _perDegree, 120 + east / (_perDegree * 0.9135454576));

RouteSegment segment(String mode, List<LatLng> points, {double minutes = 10, double wait = 0}) => RouteSegment.fromJson({
      'mode': mode,
      'minutes': minutes,
      'wait_minutes': wait,
      'coordinates': [
        for (final p in points) [p.longitude, p.latitude],
      ],
    });

RouteOption option(String mode, List<RouteSegment> segments) => RouteOption.fromJson({
      'mode': mode,
      'segments': [
        for (final s in segments)
          {
            'mode': s.mode,
            'minutes': s.minutes,
            'wait_minutes': s.waitMinutes,
            'coordinates': [
              for (final p in s.points) [p.longitude, p.latitude],
            ],
          },
      ],
    });

void main() {
  // 一條先往北 1000 公尺、再往東 1000 公尺的路
  final corner = [at(0), at(1000), at(1000, 1000)];

  group('位置對到折線上 snapToLine', () {
    test('在路線旁邊：對到垂直投影的那一點，並算出離路線多遠、走了多遠', () {
      final snap = snapToLine(corner, at(400, 25))!;

      expect(snap.index, 0);
      expect(snap.offMeters, closeTo(25, 0.5));
      expect(snap.alongMeters, closeTo(400, 0.5));
      expect(snap.totalMeters, closeTo(2000, 1));
      expect(snap.point.latitude, closeTo(at(400).latitude, 1e-6));
      expect(snap.point.longitude, closeTo(120, 1e-6));
    });

    test('轉彎之後：對到第二段', () {
      final snap = snapToLine(corner, at(1010, 300))!;

      expect(snap.index, 1);
      expect(snap.offMeters, closeTo(10, 0.5));
      expect(snap.alongMeters, closeTo(1300, 1));
    });

    test('超出線段的兩端：對到端點', () {
      expect(snapToLine(corner, at(-50))!.alongMeters, closeTo(0, 0.01));
      expect(snapToLine(corner, at(-50))!.offMeters, closeTo(50, 0.5));
      expect(snapToLine(corner, at(1000, 1200))!.alongMeters, closeTo(2000, 1));
    });

    test('路線繞回來時，進度不會跳回前面走過的那一段', () {
      // 往北 500 公尺再原路折回來：兩段疊在一起
      final outAndBack = [at(0), at(500), at(0)];
      final me = at(100, 5);

      expect(snapToLine(outAndBack, me)!.alongMeters, closeTo(100, 1)); // 沒有限制：對到去程
      expect(snapToLine(outAndBack, me, minAlong: 600)!.alongMeters, closeTo(900, 1)); // 已經走了 600：對到回程
    });

    test('只有一個點或沒有點', () {
      expect(snapToLine(const [], at(0)), isNull);
      expect(snapToLine([at(0)], at(30))!.offMeters, closeTo(30, 0.5));
    });
  });

  group('在方案上的進度 locateOnRoute', () {
    // 走 600 公尺到站牌 → 搭公車 2000 公尺（候車 8 分）→ 下車再走 400 公尺
    final transit = option('公車', [
      segment('步行', [at(0), at(600)], minutes: 8),
      segment('公車', [at(600), at(600, 2000)], minutes: 6, wait: 8),
      segment('步行', [at(600, 2000), at(1000, 2000)], minutes: 5),
    ]);

    test('走到一半：已走距離、剩餘距離與時間', () {
      final p = locateOnRoute(transit, at(300, 10))!;

      expect(p.segment, 0);
      expect(p.doneMeters, closeTo(300, 1));
      expect(p.totalMeters, closeTo(3000, 2));
      expect(p.remainingMeters, closeTo(2700, 2));
      // 這一小段剩一半 4 分 ＋ 公車 6 分與候車 8 分 ＋ 最後步行 5 分
      expect(p.remainingMinutes, closeTo(23, 0.1));
      expect(p.fraction, closeTo(0.1, 0.01));
    });

    test('已經在公車上：候車時間不再算', () {
      final p = locateOnRoute(transit, at(600, 1000))!;

      expect(p.segment, 1);
      expect(p.doneMeters, closeTo(1600, 2));
      expect(p.remainingMinutes, closeTo(3 + 5, 0.1)); // 公車剩一半 3 分 ＋ 最後步行 5 分
    });

    test('走到終點：剩餘是 0', () {
      final p = locateOnRoute(transit, at(1000, 2000))!;

      expect(p.segment, 2);
      expect(p.remainingMeters, closeTo(0, 1));
      expect(p.remainingMinutes, closeTo(0, 0.1));
      expect(p.fraction, closeTo(1, 0.001));
    });

    test('進度只會往前：傳了 minDone 就不會對回前面的小段', () {
      // 人在第一段旁邊，但進度已經到 2700 公尺（最後一段）
      final p = locateOnRoute(transit, at(300, 10), minDone: 2700)!;

      expect(p.segment, 2);
      expect(p.doneMeters, greaterThanOrEqualTo(2699));
    });
  });

  group('切成走過的與還沒走的 splitRoute', () {
    final walk = option('步行', [
      segment('步行', corner),
    ]);

    test('還不知道人在哪：全部算還沒走', () {
      final split = splitRoute(walk, null);

      expect(split.passed, isEmpty);
      expect(split.ahead.single.$2, corner);
    });

    test('從對到的那一點切開：兩邊在那一點相接，人往前走，還沒走的那一段就變短', () {
      final early = splitRoute(walk, locateOnRoute(walk, at(400)));
      final later = splitRoute(walk, locateOnRoute(walk, at(1000, 500)));

      expect(early.passed.single.$2.length, 2); // 起點 → 我
      expect(early.ahead.single.$2.length, 3); // 我 → 轉角 → 終點
      expect(early.passed.single.$2.last, early.ahead.single.$2.first);

      expect(later.passed.single.$2.length, 3); // 起點 → 轉角 → 我
      expect(later.ahead.single.$2.length, 2); // 我 → 終點
    });

    test('有好幾小段：前面的整段算走過，後面的整段算還沒走', () {
      final transit = option('公車', [
        segment('步行', [at(0), at(600)]),
        segment('公車', [at(600), at(600, 2000)]),
        segment('步行', [at(600, 2000), at(1000, 2000)]),
      ]);
      final split = splitRoute(transit, locateOnRoute(transit, at(600, 1000)));

      expect(split.passed.map((p) => p.$1.mode), ['步行', '公車']);
      expect(split.ahead.map((p) => p.$1.mode), ['公車', '步行']);
    });
  });

  group('偏離路線 OffRouteDetector', () {
    final t0 = DateTime(2026, 10, 14, 13, 0, 0);

    test('門檻：步行 40、腳踏車 50、機車汽車 60 公尺', () {
      expect(offRouteThreshold('步行'), 40);
      expect(offRouteThreshold('腳踏車'), 50);
      expect(offRouteThreshold('機車'), 60);
      expect(offRouteThreshold('汽車'), 60);
    });

    test('連續兩次超過門檻才重新規劃，單獨一次不算', () {
      final d = OffRouteDetector();

      expect(d.update(offMeters: 70, mode: '步行', now: t0), isFalse);
      expect(d.isOff, isFalse);
      expect(d.update(offMeters: 80, mode: '步行', now: t0), isTrue);
      expect(d.isOff, isTrue);
    });

    test('中間回到路線上就重新累計', () {
      final d = OffRouteDetector();

      d.update(offMeters: 70, mode: '步行', now: t0);
      expect(d.update(offMeters: 10, mode: '步行', now: t0), isFalse);
      expect(d.update(offMeters: 70, mode: '步行', now: t0), isFalse);
    });

    test('重新規劃後 12 秒內不再重算', () {
      final d = OffRouteDetector();
      d.update(offMeters: 70, mode: '步行', now: t0);
      d.update(offMeters: 70, mode: '步行', now: t0);
      d.rerouted(t0);

      expect(d.update(offMeters: 70, mode: '步行', now: t0.add(const Duration(seconds: 5))), isFalse);
      expect(d.update(offMeters: 70, mode: '步行', now: t0.add(const Duration(seconds: 13))), isTrue);
    });

    test('定位誤差比門檻大時，門檻放寬到誤差；誤差超過 100 公尺不判斷', () {
      final d = OffRouteDetector();

      // 誤差 80 公尺：離路線 70 公尺還在誤差內
      expect(d.update(offMeters: 70, mode: '步行', accuracy: 80, now: t0), isFalse);
      expect(d.update(offMeters: 70, mode: '步行', accuracy: 80, now: t0), isFalse);

      // 誤差 300 公尺（例如電腦用 Wi-Fi 定位）：不管離多遠都不重算
      expect(d.update(offMeters: 900, mode: '步行', accuracy: 300, now: t0), isFalse);
      expect(d.update(offMeters: 900, mode: '步行', accuracy: 300, now: t0), isFalse);
    });

    test('搭公車、捷運時不判斷', () {
      final d = OffRouteDetector();

      expect(d.update(offMeters: 500, mode: '公車', onRide: true, now: t0), isFalse);
      expect(d.update(offMeters: 500, mode: '公車', onRide: true, now: t0), isFalse);
      expect(d.isOff, isFalse);
    });
  });

  group('模擬行走 pointOnRoute', () {
    final walk = option('步行', [
      segment('步行', corner),
    ]);

    test('沿著路線走：走了多遠就在路線上的那一點', () {
      final p = locateOnRoute(walk, pointOnRoute(walk, 1300))!;

      expect(p.doneMeters, closeTo(1300, 2));
      expect(p.offMeters, closeTo(0, 1));
    });

    test('故意走偏：離路線的距離就是偏的距離', () {
      final p = locateOnRoute(walk, pointOnRoute(walk, 400, drift: 90))!;

      expect(p.offMeters, closeTo(90, 2));
      expect(p.doneMeters, closeTo(400, 3));
    });

    test('超過終點：停在終點', () {
      expect(locateOnRoute(walk, pointOnRoute(walk, 99999))!.remainingMeters, closeTo(0, 1));
    });
  });
}
