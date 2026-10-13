// 藏寶圖頁的景點卡片與換路線，後端用假的：
// 點地圖上的另一個方案換路線 → 景點卡片的查看任務／回顧劇情／周邊好去 → 周邊地點按「前往」順路過去
// → 主路線還在，可以切回去 → 結束順路
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:playtaiwan/route_map/models.dart';
import 'package:playtaiwan/route_map/pages/treasure_map.dart';

/// 建議起點在第 1 關景點的正南方約 1.1 公里
const _start = {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'};
const _targetLat = 24.1500, _targetLng = 120.6800;

/// 腳踏車方案繞到東邊約 200 公尺的這一點，跟直直往北的步行方案分得開
const _bikeLat = 24.1450, _bikeLng = 120.6820;

/// 周邊地點，在起點東北方
const _shopLat = 24.1440, _shopLng = 120.6790;

/// 1×1 的透明 PNG，當地圖底圖
final _tile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _ok(Object? result) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': true, 'message': '', 'Result': result})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _option(String mode, String summary, List<List<double>> coordinates) => {
      'mode': mode, 'minutes': 15, 'distance_km': 1.1, 'summary': summary, 'is_chosen': mode == '步行',
      'segments': [
        {'mode': mode, 'color': '#4F6B3A', 'minutes': 15, 'distance_km': 1.1, 'instruction': summary, 'coordinates': coordinates},
      ],
    };

void main() {
  testWidgets('點地圖換方案、景點卡片的三個功能、順路去周邊地點', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 測試環境沒有定位：讓定位馬上失敗，頁面會改從劇本的建議起點出發
    const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        geolocator, (call) async => throw PlatformException(code: 'unavailable', message: '測試環境沒有定位'));
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(geolocator, null));

    // 每次規劃路線時前端送的內容
    final plans = <Map<String, dynamic>>[];

    // 後端說到第 1 關的現場了沒、第 1 關破關了沒，測試中途會變
    var arrived = false;
    var cleared = false;

    final backend = MockClient((request) async {
      final path = request.url.path;
      if (!path.startsWith('/api/')) return http.Response.bytes(_tile, 200, headers: {'content-type': 'image/png'});
      if (path == '/api/Metro/Lines') return _ok([]);
      if (path.endsWith('/Nearby')) {
        return _ok([
          {
            'place_uid': 'shop-1', 'name': '豆花店', 'category': '飲食', 'type': '甜點',
            'lat': _shopLat, 'lng': _shopLng, 'distance_m': 120, 'is_open_now': true,
          },
        ]);
      }
      if (path == '/api/Route/Availability') {
        return _ok([
          {'mode': '步行', 'enabled': true, 'reason': ''},
          {'mode': '腳踏車', 'enabled': true, 'reason': ''},
        ]);
      }
      if (path == '/api/Map/7') {
        return _ok({
          'demo_mode': false,
          'reveal_radius_m': 300,
          'nodes': [
            {
              'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦',
              'lat': _targetLat, 'lng': _targetLng, 'is_unlocked': true, 'is_current': !cleared, 'is_arrived': arrived,
              'is_completed': cleared,
            },
            {
              'node_id': 102, 'node_order': 2, 'location_name': '霧中燈火', 'codename': '霧中燈火',
              'lat': 24.16, 'lng': 120.69, 'is_unlocked': cleared, 'is_current': cleared, 'fog_radius_m': 300,
            },
          ],
        });
      }
      if (path == '/api/Map/Node/101/Interact') {
        return _ok({
          'node_id': 101, 'location_name': '白牆藍瓦', 'location_subtitle': '百年老屋', 'scene_image_url': '',
          'npc_name': '墨先生', 'npc_role': '說書人', 'npc_avatar_url': '', 'npc_dialogue': '霓霓說：歡迎來到白牆藍瓦。走吧！',
        });
      }
      if (path == '/api/Task/Node/101') {
        return _ok({
          'node': {'node_id': 101, 'opening_text': '這棟老屋藏著第一個線索。', 'success_text': null},
          'npc': {'npc_name': '墨先生', 'npc_role': '說書人', 'npc_avatar_url': ''},
          'tasks': [
            {
              'task_id': 1, 'type_name': '選擇題', 'task_describe': '屋瓦是什麼顏色？', 'pass': 0,
              'options': [
                {'option_key': 'A', 'option_text': '藍色'},
              ],
            },
          ],
        });
      }
      if (path == '/api/Route/Plan') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        plans.add(body);
        final start = (body['start'] as Map<String, dynamic>?) ?? _start;
        final from = [start['lng'] as double, start['lat'] as double];
        final points = body['points'] as List?;
        if (points != null) {
          // 順路：直直走到那個地點
          final to = points.single as Map<String, dynamic>;
          return _ok({
            'start': start, 'stops': [], 'warnings': [],
            'legs': [
              {
                'leg_order': 1, 'direction': '去程', 'from_name': '出發地', 'to_name': to['name'],
                'options': [
                  _option('步行', '步行去吃豆花', [from, [to['lng'] as double, to['lat'] as double]]),
                ],
              },
            ],
          });
        }
        return _ok({
          'start': start, 'stops': [], 'warnings': [],
          'legs': [
            {
              'leg_order': 1, 'direction': '去程', 'from_name': '出發地', 'to_name': '白牆藍瓦',
              'options': [
                _option('步行', '步行直直走', [from, [_targetLng, _targetLat]]),
                _option('腳踏車', '腳踏車繞東邊', [from, [_bikeLng, _bikeLat], [_targetLng, _targetLat]]),
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

    Future<void> closeSheet() async {
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await wait(1);
    }

    final story = RouteStory.fromJson({
      'story_id': 7, 'story_title': '測試劇本', 'node_count': 2, 'suggested_start': _start, 'nodes': [],
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TreasureMap(story: story))));
      await wait(3);
      expect(plans, hasLength(1));
      expect(find.text('步行直直走'), findsOneWidget);

      // ── 點地圖上灰色的另一個方案：改走那一條，不用再問後端 ──
      final map = find.byType(FlutterMap);
      final camera = tester.widget<FlutterMap>(map).mapController!.camera;
      await tester.tapAt(tester.getTopLeft(map) + camera.latLngToScreenOffset(const LatLng(_bikeLat, _bikeLng)));
      await wait(1);
      expect(find.text('腳踏車繞東邊'), findsOneWidget);
      expect(find.text('步行直直走'), findsNothing);
      expect(plans, hasLength(1));

      // ── 景點卡片：周邊好去、查看任務、回顧劇情（沒有開始導航）──
      await tester.tap(find.text('1'));
      await wait(1);
      expect(find.text('周邊好去'), findsOneWidget);
      expect(find.text('開始導航'), findsNothing);

      // 還沒抵達：任務還不能做、劇情也還沒發生，卡片上只有周邊好去
      expect(find.text('查看任務'), findsNothing);
      expect(find.text('回顧劇情 >>'), findsNothing);

      // 抵達之後（每 20 秒問一次後端的進度）才出現查看任務和回顧劇情
      arrived = true;
      await tester.pump(const Duration(seconds: 21));
      await wait(2);
      expect(find.text('查看任務'), findsOneWidget);
      expect(find.text('回顧劇情 >>'), findsOneWidget);

      // 目前這一關的卡片沒有「前往」（路線進關卡就規劃好了），也不會有開 Google 地圖的「前往地址」
      expect(find.text('前往'), findsNothing);
      expect(find.text('前往地址'), findsNothing);

      await tester.tap(find.text('查看任務'));
      await wait(2);
      expect(find.text('已通過 0 / 1 題'), findsOneWidget);
      expect(find.text('屋瓦是什麼顏色？'), findsOneWidget);
      await closeSheet();

      // 回顧劇情：整頁的劇情畫面，名牌寫是誰在說，一次一句，點對話框看下一句
      await tester.tap(find.text('回顧劇情 >>'));
      await wait(2);
      expect(find.text('百年老屋'), findsOneWidget);
      expect(find.text('旁白'), findsOneWidget); // 這一站的開場劇情是旁白
      expect(find.text('這棟老屋藏著第一個線索。'), findsOneWidget);
      expect(find.text('點擊繼續'), findsOneWidget);

      // NPC 另外有話說：開頭寫「霓霓說：」的算霓霓說的，而且拆成一句一句
      await tester.tap(find.text('這棟老屋藏著第一個線索。'));
      await wait(1);
      expect(find.text('霓霓'), findsOneWidget);
      expect(find.text('歡迎來到白牆藍瓦。'), findsOneWidget);
      await tester.tap(find.text('歡迎來到白牆藍瓦。'));
      await wait(1);
      expect(find.text('走吧！'), findsOneWidget);

      // 最後一句點了就關掉，回到地圖（點對話框裡的字：右下角的提示這時候被「已抵達」的提示條蓋住）
      expect(find.text('點擊結束'), findsOneWidget);
      await tester.tap(find.text('走吧！'));
      await wait(2);
      expect(find.text('點擊結束'), findsNothing);
      expect(find.text('回顧劇情 >>'), findsOneWidget);

      // ── 周邊好去 → 選一個地點 → 卡片上按「前往」：順路的路線規劃出來，主路線還在 ──
      await tester.tap(find.text('周邊好去'));
      await wait(2);
      await tester.tap(find.text('豆花店'));
      await wait(2);
      await tester.tap(find.text('前往'));
      await wait(2);

      expect(plans, hasLength(2));
      expect(plans.last.containsKey('story_id'), isFalse);
      expect(((plans.last['points'] as List).single as Map)['name'], '豆花店');
      expect(find.text('出發地 → 豆花店'), findsOneWidget);
      expect(find.text('出發地 → 白牆藍瓦'), findsOneWidget);

      // 現在走的是順路那一條，「改走這條路線」在主路線下面（「結束順路」的上面）
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(y('改走這條路線'), lessThan(y('結束順路')));

      // 切回主路線：按鈕換到順路那一條下面，兩條都還在
      await tester.tap(find.text('改走這條路線'));
      await wait(1);
      expect(y('改走這條路線'), greaterThan(y('結束順路')));
      expect(find.text('出發地 → 豆花店'), findsOneWidget);

      // ── 結束順路：順路的路線拿掉，主路線重新規劃 ──
      await tester.tap(find.text('結束順路'));
      await wait(2);
      expect(find.text('結束順路'), findsNothing);
      expect(find.text('出發地 → 豆花店'), findsNothing);
      expect(find.text('出發地 → 白牆藍瓦'), findsOneWidget);
      expect(plans, hasLength(3));
      expect(plans.last['story_id'], 7);

      // ── 第 1 關破關了（後端的進度每 20 秒問一次）：它的卡片上有「前往」，按了在這張地圖上規劃走回去的路線，不開 Google 地圖 ──
      cleared = true;
      await tester.pump(const Duration(seconds: 21));
      await wait(3);
      final before = plans.length;
      await tester.tap(find.text('1'));
      await wait(1);
      expect(find.text('前往地址'), findsNothing);
      await tester.tap(find.text('前往'));
      await wait(2);
      expect(plans, hasLength(before + 1));
      expect(plans.last.containsKey('story_id'), isFalse);
      expect(((plans.last['points'] as List).single as Map)['name'], '白牆藍瓦');
      expect(find.text('結束順路'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });
}
