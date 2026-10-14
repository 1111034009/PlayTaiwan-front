// 做任務，後端用假的：
// 1. 地圖面板：抵達後出現「做任務」（關卡選單旁邊的圓形按鈕拿掉了），按了開答題頁，關掉回來地圖重新問進度、開下一關，
//    並告訴外面破了哪一關；答題頁開著的時候不處理破關
// 2. 答題頁：選擇題答錯 → 出現提示 → 答對；文字題答對 → 這一關破關 → 不用按，自己關掉回地圖
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playtaiwan/pages/story_task_page.dart';
import 'package:playtaiwan/route_map/models.dart';
import 'package:playtaiwan/route_map/pages/treasure_map.dart';
import 'package:playtaiwan/route_map/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1×1 的透明 PNG，當地圖底圖
final _tile = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _ok(Object? result) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': true, 'message': '', 'Result': result})),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _fail(int status, String message) => http.Response.bytes(
      utf8.encode(jsonEncode({'isSuccess': false, 'message': message, 'Result': null})),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  testWidgets('地圖面板：抵達後按「做任務」開答題頁，回來重新問進度、開下一關', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    const geolocator = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        geolocator, (call) async => throw PlatformException(code: 'unavailable', message: '測試環境沒有定位'));
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(geolocator, null));

    // 第 1 關抵達了沒、破關了沒：測試裡自己改，假裝後端的進度變了
    var arrived = false, cleared = false;
    final backend = MockClient((request) async {
      final path = request.url.path;
      if (!path.startsWith('/api/')) return http.Response.bytes(_tile, 200, headers: {'content-type': 'image/png'});
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
          'nodes': [
            {
              'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦', 'place_name': '臺中州廳',
              'lat': 24.1440, 'lng': 120.6790, 'is_unlocked': true, 'is_current': !cleared, 'is_arrived': arrived, 'is_completed': cleared,
            },
            {
              'node_id': 102, 'node_order': 2, 'location_name': '第二章', 'codename': '霧中燈火',
              'lat': 24.1500, 'lng': 120.6800, 'is_unlocked': cleared, 'is_current': cleared, 'fog_radius_m': 300,
            },
          ],
        });
      }
      if (path == '/api/Route/Plan') return _fail(400, '測試不規劃路線');
      return http.Response('not found', 404);
    });

    Future<void> wait(int ticks) async {
      for (var i = 0; i < ticks; i++) {
        await tester.pump(const Duration(milliseconds: 600));
      }
    }

    final story = RouteStory.fromJson({
      'story_id': 7, 'story_title': '測試劇本', 'node_count': 2, 'nodes': [],
      'suggested_start': {'lat': 24.1400, 'lng': 120.6800, 'name': '建議起點'},
    });

    final opened = <MapNode>[];
    final stageCleared = <int>[];
    final closeTasks = Completer<void>();
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TreasureMap(
            story: story,
            embedded: true,
            // 假的答題頁：一開任務就全部做完了，但頁面還開著，等測試叫它關
            onDoTasks: (node, myLocation) async {
              opened.add(node);
              cleared = true;
              await closeTasks.future;
            },
            onStageCleared: (node) => stageCleared.add(node.nodeId),
          ),
        ),
      ));
      await wait(12);

      // 關卡選單旁邊的圓形按鈕拿掉了
      expect(find.byIcon(Icons.center_focus_strong, skipOffstage: false), findsNothing);
      expect(find.byTooltip('地圖回到這一關', skipOffstage: false), findsNothing);

      // 還沒抵達：只有「我到了」，沒有「做任務」
      expect(find.textContaining('我到了', skipOffstage: false), findsWidgets);
      expect(find.text('做任務', skipOffstage: false), findsNothing);

      // 抵達之後（每 20 秒問一次後端的進度）出現「做任務」，檢查進度還在
      arrived = true;
      await tester.pump(const Duration(seconds: 21));
      await wait(2);
      final doTasks = find.text('做任務', skipOffstage: false);
      expect(doTasks, findsOneWidget);
      expect(find.text('任務做完了，檢查進度', skipOffstage: false), findsOneWidget);

      // 按「做任務」：開的是目前這一關。答題頁還開著的時候，就算過了定時檢查的時間也不處理破關
      await tester.scrollUntilVisible(doTasks, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(doTasks);
      await wait(1);
      expect(opened.map((n) => n.nodeId), [101]);
      await tester.pump(const Duration(seconds: 21));
      await wait(2);
      expect(stageCleared, isEmpty);
      expect(find.textContaining('第 1 關破關'), findsNothing);

      // 答題頁關掉：地圖重新問進度，第 1 關破關、進第 2 關，告訴外面破的是哪一關（外面用來跳明信片）
      closeTasks.complete();
      await wait(3);
      expect(stageCleared, [101]);
      expect(find.textContaining('第 1 關破關'), findsOneWidget);
      expect(find.text('做任務', skipOffstage: false), findsNothing); // 第 2 關還沒抵達

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => backend);
  });

  testWidgets('答題頁：選擇題答錯有提示、答對通過，全部通過就破關、自己關掉回地圖', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final passed = <int>{};
    var wrong = 0;
    final answers = <Map<String, dynamic>>[];
    final backend = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/Task/Node/101') {
        return _ok({
          'node': {
            'node_id': 101, 'story_id': 7, 'node_order': 1, 'title': '第一章',
            'opening_text': '州廳的鐘聲停了。', 'success_text': passed.length == 2 ? '鐘聲又響了起來。' : null,
          },
          'npc': {'npc_name': '墨先生', 'npc_role': '守鐘人', 'npc_avatar_url': '', 'npc_voice': 'a'},
          'my_seat_no': 1,
          'progress': {'passed': passed.length, 'total': 2, 'all_passed': passed.length == 2},
          'tasks': [
            {
              'task_id': 11, 'type_id': 6, 'type_name': '文化問答', 'answer_mode': 'choice', 'task_describe': '州廳是哪一年落成的？',
              'options': [
                {'option_key': 'A', 'option_text': '1913'},
                {'option_key': 'B', 'option_text': '1934'},
              ],
              'pass': passed.contains(11) ? 1 : 0, 'wrong_count': wrong, 'hint_available': wrong > 0 && !passed.contains(11),
            },
            {
              'task_id': 12, 'type_id': 2, 'type_name': '跨關集結', 'answer_mode': 'text', 'task_describe': '鐘樓上寫了哪兩個字？',
              'options': [], 'pass': passed.contains(12) ? 1 : 0, 'wrong_count': 0, 'hint_available': false,
            },
          ],
        });
      }
      if (path == '/api/Task/11/Hint') {
        return _ok({'task_id': '11', 'npc_name': '墨先生', 'hint_text': '比大正年間早一點。', 'is_available': true});
      }
      if (path == '/api/Task/Answer') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        answers.add(body);
        final correct = body['task_id'] == 11 ? body['selected_option_key'] == 'A' : body['text_answer'] == '報時';
        if (correct) {
          passed.add(body['task_id'] as int);
        } else {
          wrong++;
        }
        return _ok({
          'is_correct': correct, 'pass': correct ? 1 : 0, 'is_pending_review': false,
          'feedback_message': correct ? '答對了，墨先生點了點頭。' : '不對喔，再想想。',
          'node_progress': {'passed': passed.length, 'total': 2, 'all_passed': passed.length == 2},
          'node_completed': passed.length == 2, 'story_completed': false,
        });
      }
      return http.Response('not found', 404);
    });

    final node = MapNode.fromJson({
      'node_id': 101, 'node_order': 1, 'location_name': '第一章', 'codename': '白牆藍瓦', 'place_name': '臺中州廳',
      'lat': 24.1440, 'lng': 120.6790, 'is_unlocked': true, 'is_current': true, 'is_arrived': true,
    });

    // 答題頁關掉時回給開它的人的結果
    StoryTaskResult? closed;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => closed = await Navigator.of(context).push(MaterialPageRoute<StoryTaskResult>(
                  builder: (_) => StoryTaskPage(node: node, myLocation: () async => PlacePoint(lat: 24.1441, lng: 120.6791)),
                )),
                child: const Text('開答題頁'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('開答題頁'));
      await tester.pumpAndSettle();

      expect(find.text('做任務・臺中州廳'), findsOneWidget);
      expect(find.text('墨先生'), findsOneWidget);
      expect(find.text('州廳的鐘聲停了。'), findsOneWidget);
      expect(find.text('已通過 0 / 2 題'), findsOneWidget);
      expect(find.text('提示'), findsNothing); // 選擇題要先答錯一次才有提示

      // 沒選就送出：不打後端
      await tester.tap(find.text('送出答案').first);
      await tester.pump();
      expect(find.text('請先選一個答案'), findsOneWidget);
      expect(answers, isEmpty);

      // 選錯的：後端說答錯，出現提示
      await tester.tap(find.text('B. 1934'));
      await tester.tap(find.text('送出答案').first);
      await tester.pumpAndSettle();
      expect(answers.single, {'task_id': 11, 'gps_lat': 24.1441, 'gps_lon': 120.6791, 'selected_option_key': 'B'});
      expect(find.text('不對喔，再想想。'), findsOneWidget);
      await tester.tap(find.text('提示'));
      await tester.pumpAndSettle();
      expect(find.text('墨先生的提示'), findsOneWidget);
      expect(find.text('比大正年間早一點。'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      // 改選對的：這一題通過，只剩文字題要送
      await tester.tap(find.text('A. 1913'));
      await tester.tap(find.text('送出答案').first);
      await tester.pumpAndSettle();
      expect(find.text('答對了，墨先生點了點頭。'), findsOneWidget);
      expect(find.text('已通過 1 / 2 題'), findsOneWidget);
      expect(find.text('送出答案'), findsOneWidget);

      // 文字題答對：這一關破關。最後一題的結果先看得到，不用按任何東西，一下子頁面就自己關掉回地圖
      await tester.enterText(find.byType(TextField), ' 報時 ');
      await tester.ensureVisible(find.text('送出答案'));
      await tester.tap(find.text('送出答案'));
      await tester.pumpAndSettle();
      expect(answers.last, {'task_id': 12, 'gps_lat': 24.1441, 'gps_lon': 120.6791, 'text_answer': '報時'});
      expect(find.text('已通過 2 / 2 題'), findsOneWidget);
      expect(find.text('鐘聲又響了起來。'), findsOneWidget);
      expect(closed, isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('開答題頁'), findsOneWidget);
      expect(find.byType(StoryTaskPage), findsNothing);
      expect(closed, (cleared: true, photo: null));

      expect(tester.takeException(), isNull);
    }, () => backend);
  });
}
