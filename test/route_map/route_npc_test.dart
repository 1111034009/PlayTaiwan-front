// 地圖上的 NPC 與隊友位置，後端用假的：
// 後端說要提醒（太熱、午餐時間）→ NPC 一則一則跳出來 → 看推薦的店家 → 同一個 key 不再跳 → 換成下雨是新的 key，再跳一次
// → 使用者自己點 NPC 問天氣、問吃什麼
// 寬螢幕（NPC 在右下角）和手機版面（NPC 在左下角、貼著面板）各跑一次
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtaiwan/route_map/models.dart';
import 'package:playtaiwan/route_map/pages/treasure_map.dart';
import 'package:playtaiwan/route_map/widgets/npc_buddy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _start = {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'};
const _targetLat = 24.1500, _targetLng = 120.6800;

/// 1×1 的透明 PNG，當地圖底圖
final _tile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _ok(Object? result) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': true, 'message': '', 'Result': result})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _shop = {
  'place_id': 'r1', 'name': '山河魯肉飯', 'type': '小吃',
  'lat': 24.1445, 'lng': 120.6805, 'distance_m': 350, 'is_open_now': true,
};

const _hot = {
  'key': 'weather-20261013-09-hot', 'type': 'weather', 'kind': 'hot',
  'message': '目前天氣：晴，氣溫 33°C。天氣很熱，記得多喝水、做好防曬。',
  'weather': {'condition': 'clear', 'is_raining': false, 'alert': 'hot'},
  'places': [],
};

const _lunch = {
  'key': 'meal-20261013-lunch', 'type': 'meal', 'kind': 'lunch',
  'message': '午餐時間到了！附近 350 公尺有「山河魯肉飯」。',
  'weather': null,
  'places': [_shop],
};

const _raining = {
  'key': 'weather-20261013-12-raining', 'type': 'weather', 'kind': 'raining',
  'message': '目前天氣：陰有雨。外面正在下雨，記得帶傘，路滑小心走。',
  'weather': {'condition': 'rain', 'is_raining': true, 'alert': 'raining'},
  'places': [],
};

void main() {
  // 手機版面用 880 寬來跑（不到 900 就是地圖在上、面板從下方拉起）：測試環境的字型每個字都是正方形、比真的字寬很多，
  // 用真的手機寬度時連地圖右下的 OpenStreetMap 標示都會排不下，跟實機不一樣
  for (final (label, size) in [('寬螢幕', const Size(1400, 1000)), ('手機版面', const Size(880, 900))]) {
    testWidgets('NPC 照後端說的提醒跳出來、同一則不重複，還有隊友的位置（$label）', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 手機裡已經記著一則跳過的提醒
      SharedPreferences.setMockInitialValues({
        'npc_reminded_keys': ['weather-20261012-15-hot'],
      });

      // 測試環境沒有定位：讓定位馬上失敗，頁面會改從劇本的建議起點出發
      const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          geolocator, (call) async => throw PlatformException(code: 'unavailable', message: '測試環境沒有定位'));
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(geolocator, null));

      // 後端現在說要提醒什麼，測試中途會換
      var reminders = <Map<String, dynamic>>[_hot, _lunch];
      var reminderCalls = 0;
      Uri? lastReminderRequest;

      final backend = MockClient((request) async {
        final path = request.url.path;
        if (!path.startsWith('/api/')) return http.Response.bytes(_tile, 200, headers: {'content-type': 'image/png'});
        if (path == '/api/Metro/Lines' || path.endsWith('/Nearby')) return _ok([]);
        if (path == '/api/Route/Availability') {
          return _ok([
            {'mode': '步行', 'enabled': true, 'reason': ''},
          ]);
        }
        if (path == '/api/Map/7') {
          return _ok({
            'demo_mode': false,
            'reveal_radius_m': 300,
            'nodes': [
              {
                'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦',
                'lat': _targetLat, 'lng': _targetLng, 'is_unlocked': true, 'is_current': true,
              },
            ],
          });
        }
        if (path == '/api/Map/Node/101/Interact') {
          return _ok({'npc_name': '墨先生', 'npc_avatar_url': '', 'npc_dialogue': '歡迎。'});
        }
        if (path == '/api/Map/Reminders') {
          reminderCalls++;
          lastReminderRequest = request.url;
          return _ok({'check_after_seconds': 300, 'reminders': reminders});
        }
        if (path == '/api/Map/NearbyFood') {
          return _ok({'meal': '下午茶', 'message': '附近 350 公尺有「山河魯肉飯」，想吃點東西嗎？', 'places': [_shop]});
        }
        if (path == '/api/Map/Weather') {
          return _ok({'message': '目前天氣：多雲，氣溫 26°C。天氣不錯，很適合到處走走。', 'condition': 'cloudy', 'is_raining': false});
        }
        if (path == '/api/Pair/Story/7/Locations') {
          return _ok({
            'story_id': 7,
            'members': [
              {'au_id': 1, 'auth_name': '我自己', 'is_me': true, 'lat': 24.14, 'lng': 120.68, 'is_online': true},
              {'au_id': 2, 'auth_name': '小明', 'is_me': false, 'lat': 24.1460, 'lng': 120.6810, 'is_online': true},
              {'au_id': 3, 'auth_name': '還沒回報的人', 'is_me': false, 'lat': null, 'lng': null, 'is_online': false},
            ],
          });
        }
        if (path == '/api/Route/Plan') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final start = (body['start'] as Map<String, dynamic>?) ?? _start;
          return _ok({
            'start': start, 'stops': [], 'warnings': [],
            'legs': [
              {
                'leg_order': 1, 'direction': '去程', 'from_name': '出發地', 'to_name': '白牆藍瓦',
                'options': [
                  {
                    'mode': '步行', 'minutes': 15, 'distance_km': 1.1, 'summary': '步行直直走', 'is_chosen': true,
                    'segments': [
                      {
                        'mode': '步行', 'color': '#4F6B3A', 'minutes': 15, 'distance_km': 1.1, 'instruction': '步行',
                        'coordinates': [
                          [start['lng'], start['lat']],
                          [_targetLng, _targetLat],
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

      /// 等到下一次定時去問後端（每 5 分鐘）。一小步一小步等，問到就停：
      /// 一次跳五分鐘的話，泡泡可能已經跳出來又自己收起來了
      Future<void> nextPoll() async {
        final before = reminderCalls;
        for (var i = 0; i < 120 && reminderCalls == before; i++) {
          await tester.pump(const Duration(seconds: 3));
        }
        expect(reminderCalls, before + 1);
        await wait(2);
      }

      final story = RouteStory.fromJson({
        'story_id': 7, 'story_title': '測試劇本', 'node_count': 1, 'suggested_start': _start, 'nodes': [],
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: TreasureMap(story: story))));
        await wait(4);

        // 隊友畫在地圖上；自己和還沒回報位置的不畫
        expect(find.text('小明'), findsOneWidget);
        expect(find.text('我自己'), findsNothing);
        expect(find.text('還沒回報的人'), findsNothing);

        // 路線出來後問了一次後端，帶著位置和劇本
        expect(reminderCalls, 1);
        expect(lastReminderRequest!.queryParameters['story_id'], '7');
        expect(lastReminderRequest!.queryParameters['lat'], '24.14');

        // 後端回了兩則：一次只跳一個，先講天氣
        expect(find.textContaining('天氣很熱'), findsOneWidget);
        expect(find.textContaining('午餐時間到了'), findsNothing);

        // 收起來之後輪到用餐提醒，可以看推薦的店家、選一間回到地圖上
        await tester.tap(find.byTooltip('收起來'));
        await wait(1);
        expect(find.textContaining('天氣很熱'), findsNothing);
        expect(find.textContaining('午餐時間到了'), findsOneWidget);
        await tester.tap(find.text('看 1 間店家'));
        await wait(2);
        await tester.tap(find.text('山河魯肉飯'));
        await wait(2);
        expect(find.text('前往'), findsOneWidget);
        expect(find.textContaining('午餐時間到了'), findsNothing);
        await tester.tap(find.byTooltip('關閉'));
        await wait(1);

        // 跳過的 key 存在手機裡，原本記著的還在
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('npc_reminded_keys'),
            ['weather-20261012-15-hot', 'weather-20261013-09-hot', 'meal-20261013-lunch']);

        // 五分鐘後後端還是回同樣兩則：同一個 key 不再跳
        await nextPoll();
        expect(find.textContaining('天氣很熱'), findsNothing);
        expect(find.textContaining('午餐時間到了'), findsNothing);

        // 開始下雨是新的 key：再跳一次，15 秒後自己收起來，NPC 還在
        reminders = [_raining, _lunch];
        await nextPoll();
        expect(find.textContaining('外面正在下雨'), findsOneWidget);
        await tester.pump(const Duration(seconds: 16));
        await wait(1);
        expect(find.textContaining('外面正在下雨'), findsNothing);
        expect(find.byType(NpcBuddy), findsOneWidget);

        // 使用者自己點 NPC：天氣好也會回答；泡泡上可以換成問吃什麼
        await tester.tap(find.byTooltip('墨先生'));
        await wait(2);
        expect(find.textContaining('天氣不錯'), findsOneWidget);
        await tester.tap(find.text('吃什麼'));
        await wait(2);
        expect(find.textContaining('想吃點東西嗎'), findsOneWidget);
        expect(find.text('看 1 間店家'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      }, () => backend);
    });
  }
}
