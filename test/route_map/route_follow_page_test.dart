// 藏寶圖頁「跟著位置走」的整個流程，後端用假的、沒有開示範模式：
// 展示工具的模擬行走 → 路線跟著縮短 → 故意走偏 → 自動從現在的位置重新規劃 → 走到景點 → 模擬隊友 → 用模擬的位置確認抵達
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtaiwan/route_map/models.dart';
import 'package:playtaiwan/route_map/pages/treasure_map.dart';

/// 建議起點在第 1 關景點的正南方約 1.1 公里
const _start = {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'};
const _targetLat = 24.1500, _targetLng = 120.6800;

/// 1×1 的透明 PNG，當地圖底圖
final _tile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _ok(Object? result) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': true, 'message': '', 'Result': result})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 假的後端。[planStarts] 記下每次規劃路線時前端送的起點；[arrivals] 記下確認抵達時送的位置，送過之後第 1 關就是已抵達
MockClient _backend({
  required bool demoMode,
  required List<Map<String, dynamic>> planStarts,
  required List<Map<String, String>> arrivals,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (!path.startsWith('/api/')) return http.Response.bytes(_tile, 200, headers: {'content-type': 'image/png'});
    if (path == '/api/Metro/Lines' || path.endsWith('/Nearby')) return _ok([]);
    if (path == '/api/Route/Availability') {
      return _ok([
        {'mode': '步行', 'enabled': true, 'reason': ''},
      ]);
    }
    if (path == '/api/Map/Node/101/Arrive') {
      arrivals.add(request.url.queryParameters);
      return _ok(null);
    }
    if (path == '/api/Map/7') {
      return _ok({
        'demo_mode': demoMode,
        'reveal_radius_m': 300,
        'nodes': [
          {
            'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦',
            'lat': _targetLat, 'lng': _targetLng, 'is_unlocked': true, 'is_current': true, 'is_arrived': arrivals.isNotEmpty,
          },
          {
            'node_id': 102, 'node_order': 2, 'location_name': '霧中燈火', 'codename': '霧中燈火',
            'lat': 24.16, 'lng': 120.69, 'is_unlocked': false, 'is_current': false, 'fog_radius_m': 300,
          },
        ],
      });
    }
    if (path == '/api/Route/Plan') {
      // 路線：前端送來的起點直直走到景點
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final start = (body['start'] as Map<String, dynamic>?) ?? _start;
      planStarts.add(start);
      final segment = {
        'mode': '步行', 'color': '#4F6B3A', 'minutes': 15, 'distance_km': 1.1, 'instruction': '步行到白牆藍瓦',
        'coordinates': [
          [start['lng'], start['lat']],
          [_targetLng, _targetLat],
        ],
      };
      return _ok({
        'start': start,
        'stops': [],
        'warnings': [],
        'legs': [
          {
            'leg_order': 1, 'direction': '去程', 'from_name': '出發地', 'to_name': '白牆藍瓦',
            'options': [
              {'mode': '步行', 'minutes': 15, 'distance_km': 1.1, 'summary': '步行 1.1 公里', 'is_chosen': true, 'segments': [segment]},
            ],
          },
        ],
      });
    }
    return http.Response('not found', 404);
  });
}

/// 寬螢幕；測試環境沒有定位：讓定位馬上失敗，頁面會改從劇本的建議起點出發
void _prepare(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      geolocator, (call) async => throw PlatformException(code: 'unavailable', message: '測試環境沒有定位'));
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(geolocator, null));
}

Future<void> _wait(WidgetTester tester, int ticks) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void main() {
  testWidgets('模擬行走：路線跟著縮短，走偏了自動重新規劃，走到景點後用模擬的位置確認抵達；還有模擬隊友', (tester) async {
    _prepare(tester);
    final planStarts = <Map<String, dynamic>>[];
    final arrivals = <Map<String, String>>[];
    final backend = _backend(demoMode: false, planStarts: planStarts, arrivals: arrivals);
    Future<void> wait(int ticks) => _wait(tester, ticks);

    final story = RouteStory.fromJson({
      'story_id': 7, 'story_title': '測試劇本', 'node_count': 2, 'suggested_start': _start, 'nodes': [],
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TreasureMap(story: story, demoTools: true))));

      // 載入藏寶圖 → 定位（測試環境沒有定位，改從建議起點出發）→ 規劃第 1 關的路線
      await wait(3);
      expect(planStarts, hasLength(1));
      expect(planStarts.single['name'], '建議起點');

      // 開始模擬行走（後端沒開示範模式也有這顆按鈕）
      final simulate = find.text('模擬沿路線走');
      await tester.scrollUntilVisible(simulate, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(simulate);
      await wait(5);

      // 路線跟著縮短：出現「還剩…」，已走的比例大於 0，而且沒有多打一次後端
      expect(find.textContaining('還剩', skipOffstage: false), findsOneWidget);
      expect(find.text('已走 0%', skipOffstage: false), findsNothing);
      expect(find.textContaining('在路線上', skipOffstage: false), findsOneWidget);
      expect(planStarts, hasLength(1));

      // 故意走偏：連續兩次離路線超過 40 公尺，自動從現在的位置重新規劃
      await tester.tap(find.text('故意走偏'));
      await wait(4);

      expect(planStarts, hasLength(2));
      expect(planStarts.last['name'], '我的位置');
      expect(planStarts.last['lat'] as double, greaterThan(24.1405)); // 已經往北走了一段
      expect(planStarts.last['lng'] as double, greaterThan(120.6805)); // 而且偏到路線東邊
      expect(find.text('偏離路線，已從現在的位置重新規劃'), findsOneWidget);

      // 重新規劃後繼續沿著新路線走到景點（提示幾秒後會自己消失，所以一步一步等到它出現），途中不會再重算
      final arrived = find.textContaining('模擬走到「白牆藍瓦」');
      for (var i = 0; i < 90 && arrived.evaluate().isEmpty; i++) {
        await wait(1);
      }

      expect(arrived, findsOneWidget);
      expect(planStarts, hasLength(2));
      expect(find.text('到景點了', skipOffstage: false), findsOneWidget);
      expect(find.text('模擬沿路線走', skipOffstage: false), findsOneWidget); // 走完自動停下來
      await wait(8); // 等「模擬走到…」的提示消失，免得蓋住下面的按鈕

      // 模擬隊友：三個假的隊友畫在地圖上，再按一次收起來
      final mates = find.text('模擬隊友');
      await tester.scrollUntilVisible(mates, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(mates);
      await wait(2);
      for (final name in ['小安', '阿哲', '小美']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      await tester.tap(find.text('收起模擬隊友'));
      await wait(1);
      expect(find.text('小安'), findsNothing);

      // 我的位置已經模擬走到景點：按「我到了」，送給後端確認抵達的就是景點的位置
      expect(arrivals, isEmpty);
      final here = find.text('我到了「白牆藍瓦」');
      await tester.scrollUntilVisible(here, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(here);
      await wait(2);

      expect(arrivals, hasLength(1));
      expect(double.parse(arrivals.single['lat']!), closeTo(_targetLat, 0.0005)); // 50 公尺內
      expect(double.parse(arrivals.single['lng']!), closeTo(_targetLng, 0.0005));
      expect(find.textContaining('已抵達「白牆藍瓦」'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });

  testWidgets('沒開展示工具：後端開了示範模式也沒有模擬行走和模擬隊友', (tester) async {
    _prepare(tester);
    final backend = _backend(demoMode: true, planStarts: [], arrivals: []);
    final story = RouteStory.fromJson({
      'story_id': 7, 'story_title': '測試劇本', 'node_count': 2, 'suggested_start': _start, 'nodes': [],
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TreasureMap(story: story))));
      await _wait(tester, 3);

      // 捲到路線下面的破關按鈕：有模擬行走的話，按鈕會排在它上面
      final clear = find.text('示範：破第 1 關');
      await tester.scrollUntilVisible(clear, 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('步行 1.1 公里'), findsWidgets);
      expect(find.text('模擬沿路線走'), findsNothing);
      expect(find.text('故意走偏'), findsNothing);
      expect(find.text('模擬隊友'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });
}
