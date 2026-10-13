// 地圖頁的外殼（pages/story_route_map_page.dart），後端用假的、手機大小的畫面：
// 用正在進行的劇本開地圖，上列和導覽列是 App 自己的，右下角的貓當地圖上的 NPC，提醒的泡泡從牠旁邊跳出來
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtaiwan/block/ai_talk_button.dart';
import 'package:playtaiwan/block/navigationbar.dart';
import 'package:playtaiwan/block/topbar.dart';
import 'package:playtaiwan/pages/story_route_map_page.dart';
import 'package:playtaiwan/route_map/pages/treasure_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1×1 的透明 PNG，當地圖底圖
final _tile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _ok(Object? result) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': true, 'message': '', 'Result': result})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _story(int id, String title) => {
      'story_id': id, 'story_title': title, 'node_count': 2, 'nodes': [],
      'suggested_start': {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'},
    };

void main() {
  testWidgets('用正在進行的劇本開地圖，上下是 App 自己的，貓當 NPC', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    // 用 App 真的字型來排：測試預設的字型每個字都是正方形，手機寬度會排不下，跟實機不一樣
    await tester.runAsync(() async {
      final font = FontLoader('KaiseiHarunoUmi');
      for (final weight in ['Regular', 'Medium', 'Bold']) {
        final bytes = await File('assets/fonts/KaiseiHarunoUmi-$weight.ttf').readAsBytes();
        font.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await font.load();
    });

    const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        geolocator, (call) async => throw PlatformException(code: 'unavailable', message: '測試環境沒有定位'));
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(geolocator, null));

    final mapRequests = <String>[];
    final backend = MockClient((request) async {
      final path = request.url.path;
      if (!path.startsWith('/api/')) return http.Response.bytes(_tile, 200, headers: {'content-type': 'image/png'});
      if (path == '/api/Route/Stories') return _ok([_story(9, '最新的劇本'), _story(7, '正在玩的劇本')]);
      if (path == '/api/Story/CurrentPlaying') return _ok({'story_id': 7, 'title': '正在玩的劇本', 'current_order': 2});
      if (path == '/api/Metro/Lines' || path.endsWith('/Nearby')) return _ok([]);
      if (path == '/api/Route/Availability') {
        return _ok([
          {'mode': '步行', 'enabled': true, 'reason': ''},
        ]);
      }
      if (path.startsWith('/api/Map/') && RegExp(r'^/api/Map/\d+$').hasMatch(path)) {
        mapRequests.add(path);
        return _ok({
          'demo_mode': true,
          'reveal_radius_m': 300,
          'nodes': [
            {
              'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦', 'place_name': '臺中州廳',
              'lat': 24.1440, 'lng': 120.6790, 'is_unlocked': true, 'is_current': false, 'is_arrived': true, 'is_completed': true,
            },
            {
              'node_id': 102, 'node_order': 2, 'location_name': '第二章', 'codename': '霧中燈火',
              'lat': 24.1500, 'lng': 120.6800, 'is_unlocked': true, 'is_current': true,
            },
          ],
        });
      }
      if (path == '/api/Map/Reminders') {
        return _ok({
          'check_after_seconds': 300,
          'reminders': [
            {
              'key': 'weather-test-hot', 'type': 'weather', 'kind': 'hot', 'places': [],
              'message': '目前天氣：晴，氣溫 33°C。天氣很熱，記得多喝水、做好防曬。',
              'weather': {'condition': 'clear'},
            },
          ],
        });
      }
      if (path == '/api/Route/Plan') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final start = (body['start'] as Map<String, dynamic>?) ?? {'lat': 24.1440, 'lng': 120.6790, 'name': '臺中州廳'};
        return _ok({
          'start': start, 'stops': [], 'warnings': [],
          'legs': [
            {
              'leg_order': 1, 'direction': '去程', 'from_name': start['name'], 'to_name': '霧中燈火',
              'options': [
                {
                  'mode': '步行', 'minutes': 12, 'distance_km': 0.7, 'summary': '步行 0.7 公里，約 12 分鐘', 'is_chosen': true,
                  'segments': [
                    {
                      'mode': '步行', 'color': '#2E7D32', 'minutes': 12, 'distance_km': 0.7, 'instruction': '步行到霧中燈火',
                      'coordinates': [
                        [start['lng'], start['lat']],
                        [120.6800, 24.1500],
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        });
      }
      return http.Response('not found', 404);
    });

    Future<void> wait(int ticks) async {
      for (var i = 0; i < ticks; i++) {
        await tester.pump(const Duration(milliseconds: 600));
      }
    }

    final shot = GlobalKey();
    await http.runWithClient(() async {
      await tester.pumpWidget(RepaintBoundary(
        key: shot,
        child: MaterialApp(theme: ThemeData(fontFamily: 'KaiseiHarunoUmi'), home: const StoryRouteMapPage()),
      ));
      await wait(5);

      // 開的是後端說正在進行的那一個劇本，不是清單的第一個
      expect(mapRequests, isNotEmpty);
      expect(mapRequests.toSet(), {'/api/Map/7'});
      expect(find.text('正在玩的劇本'), findsOneWidget);

      // 上列和導覽列是 App 自己的；嵌進來的地圖不再畫自己的進度條
      expect(find.byType(TopBar), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);
      expect(find.byType(TreasureMap), findsOneWidget);
      expect(find.textContaining('已破'), findsNothing);
      final topBar = tester.widget<TopBar>(find.byType(TopBar));
      expect((topBar.locationCurrent, topBar.locationTotal), (1, 2)); // 破了 1 關、總共 2 關

      // 右下角的貓當地圖上的 NPC，提醒的泡泡在牠左邊
      expect(find.byType(AiTalkButton), findsOneWidget);
      expect(find.textContaining('天氣很熱'), findsOneWidget);
      final cat = tester.getRect(find.byType(AiTalkButton));
      final bubble = tester.getRect(find.textContaining('天氣很熱'));
      expect(cat.right, greaterThan(390 - 20));
      expect(bubble.right, lessThan(cat.left));

      // 這個大小的手機上沒有東西排不下
      expect(tester.takeException(), isNull);

      // 想看畫面時設 SHOT_OUT=圖片路徑
      final out = Platform.environment['SHOT_OUT'];
      if (out != null && out.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });
}
