// 破關後的明信片，後端用假的：
// 1. 地圖頁（外殼）：做任務破關 → 不用按，明信片自動跳出來（這一關沒有拍照任務的照片，先問要不要拍一張）→ 先不要 → 回地圖，
//    已經是下一關；上列的明信片張數是後端給的
// 2. 明信片頁：用帶進來的照片、景點、劇本、節點去做 AI 明信片，做好後顯示出來
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtaiwan/block/topbar.dart';
import 'package:playtaiwan/core/app_session.dart';
import 'package:playtaiwan/pages/story_postcard_page.dart';
import 'package:playtaiwan/pages/story_route_map_page.dart';
import 'package:playtaiwan/pages/story_task_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1×1 的透明 PNG：地圖底圖、玩家的照片、做好的明信片都用它
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _ok(Object? result) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': true, 'message': '', 'Result': result})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 手機大小的畫面，用 App 真的字型來排（測試預設的字型每個字都是正方形，手機寬度會排不下）
Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    final font = FontLoader('KaiseiHarunoUmi');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      final bytes = await File('assets/fonts/KaiseiHarunoUmi-$weight.ttf').readAsBytes();
      font.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await font.load();
  });
}

Future<void> _wait(WidgetTester tester, int ticks) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_BASE_URL=http://backend.test'));

  testWidgets('地圖頁：做任務破關後明信片自動跳出來，上列的明信片張數是後端給的', (tester) async {
    await _phone(tester);
    SharedPreferences.setMockInitialValues({});

    const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        geolocator, (call) async => throw PlatformException(code: 'unavailable', message: '測試環境沒有定位'));
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(geolocator, null));

    var cleared = false;
    final answers = <Map<String, dynamic>>[];
    final backend = MockClient((request) async {
      final path = request.url.path;
      if (!path.startsWith('/api/')) return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});
      if (path == '/api/Route/Stories') {
        return _ok([
          {
            'story_id': 7, 'story_title': '正在玩的劇本', 'node_count': 2, 'nodes': [],
            'suggested_start': {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'},
          },
        ]);
      }
      if (path == '/api/Story/CurrentPlaying') return _ok({'story_id': 7, 'title': '正在玩的劇本', 'current_order': 1});
      if (path == '/api/Metro/Lines' || path.endsWith('/Nearby')) return _ok([]);
      if (path == '/api/Map/Reminders') return _ok({'check_after_seconds': 300, 'reminders': []});
      if (path == '/api/Route/Availability') {
        return _ok([
          {'mode': '步行', 'enabled': true, 'reason': ''},
        ]);
      }
      if (path == '/api/Map/7') {
        return _ok({
          'demo_mode': false,
          'reveal_radius_m': 300,
          'postcard_unlocked_count': 1,
          'postcard_total_count': 2,
          'nodes': [
            {
              'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦', 'place_name': '臺中州廳',
              'lat': 24.1440, 'lng': 120.6800, 'is_unlocked': true, 'is_current': !cleared, 'is_arrived': true, 'is_completed': cleared,
            },
            {
              'node_id': 102, 'node_order': 2, 'location_name': '第二章', 'codename': '霧中燈火',
              'lat': 24.1500, 'lng': 120.6800, 'is_unlocked': cleared, 'is_current': cleared,
            },
          ],
        });
      }
      if (path == '/api/Route/Plan') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final start = (body['start'] as Map<String, dynamic>?) ?? {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'};
        return _ok({
          'start': start, 'stops': [], 'warnings': [],
          'legs': [
            {
              'leg_order': 1, 'direction': '去程', 'from_name': start['name'], 'to_name': '下一站',
              'options': [
                {
                  'mode': '步行', 'minutes': 6, 'distance_km': 0.4, 'summary': '步行 0.4 公里，約 6 分鐘', 'is_chosen': true,
                  'segments': [
                    {
                      'mode': '步行', 'color': '#2E7D32', 'minutes': 6, 'distance_km': 0.4, 'instruction': '步行過去',
                      'coordinates': [
                        [start['lng'], start['lat']],
                        [120.6800, cleared ? 24.1500 : 24.1440],
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        });
      }
      if (path == '/api/Task/Node/101') {
        return _ok({
          'node': {'node_id': 101, 'story_id': 7, 'node_order': 1, 'title': '第一章', 'opening_text': '', 'success_text': cleared ? '鐘聲又響了起來。' : null},
          'npc': null,
          'tasks': [
            {
              'task_id': 11, 'type_name': '文化問答', 'answer_mode': 'choice', 'task_describe': '州廳是哪一年落成的？',
              'options': [
                {'option_key': 'A', 'option_text': '1913'},
                {'option_key': 'B', 'option_text': '1934'},
              ],
              'pass': cleared ? 1 : 0, 'hint_available': false,
            },
          ],
        });
      }
      if (path == '/api/Task/Answer') {
        answers.add(jsonDecode(request.body) as Map<String, dynamic>);
        cleared = true;
        return _ok({'is_correct': true, 'pass': 1, 'is_pending_review': false, 'feedback_message': '答對了。', 'node_completed': true, 'story_completed': false});
      }
      return http.Response('not found', 404);
    });

    Future<void> wait(int ticks) => _wait(tester, ticks);
    final panel = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Scrollable)).first;

    /// 按面板上的按鈕：捲到剛好看得見時它還壓在導覽列底下，再往上拉一點才按得到
    Future<void> tapInPanel(String label) async {
      await tester.scrollUntilVisible(find.text(label), 150, scrollable: panel);
      await tester.drag(panel, const Offset(0, -160), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(label));
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'KaiseiHarunoUmi'), home: const StoryRouteMapPage()));
      await wait(5);

      // 上列的明信片張數是後端給的，不是固定的 1/10
      var topBar = tester.widget<TopBar>(find.byType(TopBar));
      expect((topBar.locationCurrent, topBar.locationTotal), (0, 2));
      expect((topBar.postcardCurrent, topBar.postcardTotal), (1, 2));

      // 測試環境沒有定位：用展示工具走一步，地圖才有「我的位置」可以給答題頁
      await tapInPanel('模擬沿路線走');
      await wait(2);
      await tester.tap(find.text('暫停'));
      await wait(1);

      // 做任務 → 答對 → 這一關破關：不用按「領取明信片」，答題頁自己關掉，地圖確認破關後明信片自動跳出來
      await tapInPanel('做任務');
      await wait(2);
      expect(find.text('做任務・臺中州廳'), findsOneWidget);
      await tester.tap(find.text('A. 1913'));
      await tester.tap(find.text('送出答案'));
      await wait(5);
      expect(answers, hasLength(1));
      expect(find.text('領取明信片'), findsNothing);

      // 這一關沒有拍照任務的照片：跳出來的是問要不要拍一張，可以先不要
      expect(find.byType(StoryTaskPage), findsNothing);
      expect(find.text('做一張這一關的明信片'), findsOneWidget);
      expect(find.textContaining('拍一張「臺中州廳」的照片'), findsOneWidget);
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('從相簿選'), findsOneWidget);
      await tester.tap(find.text('先不要'));
      await wait(4);

      // 回到地圖：重新問進度，第 1 關破關、進第 2 關
      expect(find.byType(StoryPostcardPage), findsNothing);
      topBar = tester.widget<TopBar>(find.byType(TopBar));
      expect((topBar.locationCurrent, topBar.locationTotal), (1, 2));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });

  testWidgets('明信片頁：用帶進來的照片、景點、劇本、節點去做 AI 明信片', (tester) async {
    await _phone(tester);
    AppSession.token = 'test-token';
    addTearDown(() => AppSession.token = null);

    http.Request? sent;
    final backend = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/PostcardCatalog/GenerateAi') {
        sent = request;
        // 後端現在回的欄位
        return _ok({
          'p_id': 21, 'p_name': '臺中州廳 專屬明信片', 'p_summary': '州廳的午後',
          'p_imag_url': 'http://backend.test/api/PostcardCatalog/21/image',
          'download_url': 'http://backend.test/api/PostcardCatalog/21/download',
        });
      }
      if (path == '/api/PostcardCatalog/21/image') return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});
      return http.Response('not found', 404);
    });

    // 表單裡某一個欄位的值
    String? field(String name) {
      final body = utf8.decode(sent!.bodyBytes, allowMalformed: true);
      return RegExp('name="$name"\\r\\n(?:[^\\r\\n]+\\r\\n)*\\r\\n([^\\r]*)\\r\\n').firstMatch(body)?.group(1);
    }

    var next = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'KaiseiHarunoUmi'),
        home: StoryPostcardPage(
          imageBytes: _png, imageName: 'me.jpg', spotName: '臺中州廳', storyId: 7, nodeId: 101, onNext: () => next++),
      ));
      await _wait(tester, 3);

      // 送給後端的是這一關真的資料和帶進來的照片，不是寫死的測試資料
      expect(sent, isNotNull);
      expect(sent!.headers['authorization'], 'Bearer test-token');
      expect(field('spot_name'), '臺中州廳');
      expect(field('story_id'), '7');
      expect(field('node_id'), '101');
      final body = utf8.decode(sent!.bodyBytes, allowMalformed: true);
      expect(body, contains('name="user_image"; filename="me.jpg"'));

      // 做好的明信片顯示出來，沒有錯誤訊息；「前往下一站」交給開這一頁的人
      expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsOneWidget);
      expect(find.textContaining('找不到圖片檔案'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      await tester.tap(find.text('前往下一站'));
      await tester.pump();
      expect(next, 1);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });
}
