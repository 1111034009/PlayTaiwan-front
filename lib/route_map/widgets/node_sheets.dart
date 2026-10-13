import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';

// 劇本景點卡片上「回顧劇情」「查看任務」「周邊好去」打開的內容：回顧劇情是整頁，另外兩個從下方拉起。
// 這裡是展示用的簡易版：正式 App 有自己的劇情頁、任務頁、周邊頁，併過去時這三個改成開那幾頁（帶 node_id）。

/// 回顧劇情：整頁的劇情畫面（[_StoryReview]），這一站的背景圖、NPC 和旁白，一句一句看。
/// 背景圖與 NPC 來自 GET /api/Map/Node/{id}/Interact，開場與完成劇情來自 GET /api/Task/Node/{id}
/// （還沒抵達時讀不到，只有 Interact 給的那一句）。還沒抵達的這一關，後端給的背景圖是迷霧圖
void showStoryReview(BuildContext context, MapNode node) {
  final future = () async {
    final play = _tryGet('/api/Task/Node/${node.nodeId}');
    final scene = await Api.instance.get('/api/Map/Node/${node.nodeId}/Interact') as Map<String, dynamic>;
    return (scene: scene, play: await play);
  }();

  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _StoryReview(node: node, future: future),
  ));
}

/// 劇情的一句話：誰說的（旁白或 NPC 的名字）、說了什麼
typedef _StoryLine = ({String speaker, String text});

/// 把一段劇情拆成一句一句（。！？結尾），跟正式 App 的劇情頁一樣一次顯示一句。
/// 開頭寫明「某某說：」的那一段算那個人說的，其他用 [speaker]
List<_StoryLine> _storyLines(String text, String speaker) {
  final said = RegExp(r'^(.{1,8}?)說[:：]\s*').firstMatch(text);
  if (said != null) {
    speaker = said.group(1)!;
    text = text.substring(said.end);
  }
  return [
    for (final sentence in RegExp(r'[^。！？!?]+[。！？!?]*').allMatches(text).map((m) => m.group(0)!.trim()))
      if (sentence.isNotEmpty) (speaker: speaker, text: sentence),
  ];
}

/// 回顧劇情的整頁畫面，照正式 App 劇情頁的樣子：這一站的背景圖鋪滿（稍微模糊、壓暗），NPC 站在右下，
/// 下面一個對話框，左上的名牌寫是誰在說（旁白或 NPC），一次一句，點對話框看下一句，最後一句點了就關掉。
/// 正式 App 還會把台詞唸出來，這裡沒有做語音
class _StoryReview extends StatefulWidget {
  const _StoryReview({required this.node, required this.future});

  final MapNode node;
  final Future<({Map<String, dynamic> scene, Map<String, dynamic>? play})> future;

  @override
  State<_StoryReview> createState() => _StoryReviewState();
}

class _StoryReviewState extends State<_StoryReview> {
  static const _boxColor = Color(0xFFE9DFC3);
  static const _boxLine = Color(0xFF806C54);
  static const _plate = Color(0xFF8B1E12);

  Map<String, dynamic>? _scene;
  List<_StoryLine> _lines = const [];
  int _index = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.future.then<void>((data) {
      if (!mounted) return;
      final story = data.play?['node'] as Map<String, dynamic>?;
      final npcName = _text(data.scene['npc_name']);
      final opening = _text(story?['opening_text']);
      final dialogue = _text(data.scene['npc_dialogue']);
      final success = _text(story?['success_text']);
      setState(() {
        _scene = data.scene;
        _lines = [
          // 這一站的劇情是旁白。還沒抵達時拿不到開場劇情，後端給的那一句（Interact）就是這一站的旁白
          ..._storyLines(opening.isNotEmpty ? opening : dialogue, '旁白'),
          // NPC 另外有話說（跟開場劇情不一樣）才多一段 NPC 的台詞
          if (opening.isNotEmpty && dialogue.isNotEmpty && dialogue != opening) ..._storyLines(dialogue, npcName.isEmpty ? 'NPC' : npcName),
          ..._storyLines(success, '旁白'),
        ];
        if (_lines.isEmpty) _lines = const [(speaker: '旁白', text: '這一站還沒有劇情。')];
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  void _next() {
    if (_index >= _lines.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    final subtitle = _text(scene?['location_subtitle']);
    return Scaffold(
      backgroundColor: Pal.ink,
      body: Stack(fit: StackFit.expand, children: [
        if (scene != null)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
            child: _image(_text(scene['scene_image_url']), fallback: Icons.landscape_outlined),
          ),
        const IgnorePointer(child: ColoredBox(color: Color(0x55000000))),
        SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            // NPC 最多 200×285，螢幕小就跟著縮；下半身藏在對話框後面
            final npcHeight = math.min(285.0, c.maxHeight * 0.45);
            return Stack(children: [
              Positioned(
                left: 12,
                top: 10,
                right: 96,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('回顧劇情・${widget.node.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              Positioned(
                right: 12,
                top: 6,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('跳過'),
                ),
              ),
              if (scene != null && _text(scene['npc_avatar_url']).isNotEmpty)
                Positioned(
                  right: 0,
                  bottom: 16 + 58,
                  child: IgnorePointer(
                    child: Image.network(
                      _text(scene['npc_avatar_url']),
                      width: npcHeight * 200 / 285,
                      height: npcHeight,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Positioned(
                left: 9,
                right: 9,
                bottom: 16,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _error != null
                        ? _dialog(speaker: '旁白', text: _error!, hint: '點擊結束', onTap: () => Navigator.of(context).pop())
                        : scene == null
                            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Colors.white)))
                            : _dialog(
                                speaker: _lines[_index].speaker,
                                text: _lines[_index].text,
                                hint: _index >= _lines.length - 1 ? '點擊結束' : '點擊繼續',
                                onTap: _next,
                              ),
                  ),
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }

  /// 對話框：米色的框、裡面一圈咖啡色細線，左上角紅色的名牌，右下角提示點了會怎樣
  Widget _dialog({required String speaker, required String text, required String hint, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 128),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: _boxColor, borderRadius: BorderRadius.circular(8)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 118),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: _boxLine)),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 48, 12, 28),
                child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Pal.ink, height: 1.45)),
              ),
              Positioned(
                left: 6,
                top: 2,
                child: Container(
                  width: 104,
                  height: 40,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: _plate, borderRadius: BorderRadius.circular(10)),
                  child: Text(speaker,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Pal.parchment, fontSize: 16, fontWeight: FontWeight.bold, height: 1)),
                ),
              ),
              Positioned(
                right: 9,
                bottom: 4,
                child: Text(hint, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _boxLine)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 查看任務：這一站的題目和通過了沒（GET /api/Task/Node/{id}）。作答在正式 App 的任務頁，這裡只看
void showNodeTasks(BuildContext context, MapNode node) {
  final future = Api.instance.get('/api/Task/Node/${node.nodeId}').then((r) => r as Map<String, dynamic>);

  _sheet(
    context,
    title: '任務・${node.label}',
    child: _Loaded(
      future: future,
      builder: (context, play) {
        final tasks = ((play['tasks'] as List?) ?? const []).cast<Map<String, dynamic>>();
        final passed = tasks.where((t) => t['pass'] == 1).length;
        final npc = play['npc'] as Map<String, dynamic>?;
        return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), children: [
          if (npc != null) ...[_npcRow(npc), const SizedBox(height: 10)],
          Text(
            tasks.isEmpty ? '這一站沒有任務，抵達就算破關。' : '已通過 $passed / ${tasks.length} 題',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Pal.ink),
          ),
          const SizedBox(height: 6),
          for (final (i, task) in tasks.indexed) _taskCard(i + 1, task),
          if (tasks.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('作答在正式 App 的任務頁進行，這裡只列出題目和進度。', style: TextStyle(fontSize: 11, color: Pal.inkSoft)),
            ),
        ]);
      },
    ),
  );
}

/// 周邊好去：這個景點附近 800 公尺內的地點，由近到遠（GET /api/Map/{story_id}/Nearby，帶景點的位置）。
/// 點一個就關掉清單，交給 [onPick]（回到地圖上打開它的卡片，卡片上可以按「前往」）
void showNodeNearby(
  BuildContext context, {
  required int storyId,
  required MapNode node,
  required void Function(NearbyPlace place) onPick,
}) {
  final future = Api.instance.get('/api/Map/$storyId/Nearby', {
    'lat': node.point.latitude,
    'lng': node.point.longitude,
    'radius_m': 800,
    'limit': 30,
  }).then((r) => (r as List).cast<Map<String, dynamic>>().map(NearbyPlace.fromJson).where((p) => p.point != null).toList());

  _sheet(
    context,
    title: '周邊好去・${node.label}',
    child: _Loaded(
      future: future,
      builder: (context, places) => places.isEmpty
          ? _message('這個景點附近 800 公尺內沒有可以推薦的地點。')
          : _placeList(context, places, onPick, from: '離景點'),
    ),
  );
}

/// 地圖上的 NPC 提醒吃飯時列出附近的店家（GET /api/Map/NearbyFood 的 places，已經拿到了，不用再問後端）
void showFoodPlaces(
  BuildContext context, {
  required List<NearbyPlace> places,
  required void Function(NearbyPlace place) onPick,
}) {
  _sheet(context, title: '附近的店家', child: _placeList(context, places, onPick, from: '離你'));
}

/// 地點清單：點一個就關掉清單，交給 [onPick]。[from] 是距離的起點（離景點、離你）
Widget _placeList(BuildContext context, List<NearbyPlace> places, void Function(NearbyPlace place) onPick, {required String from}) {
  return ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
    for (final place in places)
      ListTile(
        dense: true,
        leading: Icon(place.isFood ? Icons.restaurant : Icons.local_see, color: place.isFood ? Pal.gold : Pal.moss),
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          place.type == null || place.type!.isEmpty ? place.categoryLabel : place.type!,
          if (place.distanceM != null) '$from ${place.distanceM} 公尺',
          if (place.isOpenNow != null) place.isOpenNow! ? '營業中' : '休息中',
        ].join('・')),
        trailing: const Icon(Icons.chevron_right, color: Pal.inkSoft),
        onTap: () {
          Navigator.of(context).pop();
          onPick(place);
        },
      ),
  ]);
}

// ─────────────────────────── 共用 ───────────────────────────

Future<Map<String, dynamic>?> _tryGet(String path) async {
  try {
    return await Api.instance.get(path) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

String _text(Object? value) => value is String ? value.trim() : '';

/// 從下方拉起的面板：標題固定在上面，內容太長可以捲，最高到螢幕的八成
void _sheet(BuildContext context, {required String title, required Widget child}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Pal.parchment,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Pal.cinnabar)),
          ),
          Flexible(child: child),
        ]),
      ),
    ),
  );
}

/// 等後端回來：載入中轉圈，失敗顯示後端說的原因（例如還沒解鎖）
class _Loaded<T> extends StatelessWidget {
  const _Loaded({required this.future, required this.builder});

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return _message('${snapshot.error}', color: Pal.cinnabar);
        return builder(context, snapshot.data as T);
      },
    );
  }
}

Widget _message(String text, {Color color = Pal.inkSoft}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Text(text, style: TextStyle(color: color)),
    );

Widget _image(String url, {required IconData fallback}) {
  final placeholder = ColoredBox(color: Pal.parchmentDeep, child: Center(child: Icon(fallback, color: Pal.inkSoft, size: 28)));
  return url.isEmpty ? placeholder : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
}

/// NPC 的頭像、名字和身分（Interact 和 Task/Node 回傳的欄位名稱一樣）
Widget _npcRow(Map<String, dynamic> npc) {
  final name = _text(npc['npc_name']);
  final role = _text(npc['npc_role']);
  return Row(children: [
    ClipOval(child: SizedBox(width: 44, height: 44, child: _image(_text(npc['npc_avatar_url']), fallback: Icons.person))),
    const SizedBox(width: 10),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.isEmpty ? 'NPC' : name, style: const TextStyle(fontWeight: FontWeight.bold, color: Pal.ink)),
        if (role.isNotEmpty)
          Text(role, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Pal.inkSoft)),
      ]),
    ),
  ]);
}

/// 一題任務：題號（通過了打勾）、題型、題目、選項；協作解謎型還有自己座位的線索
Widget _taskCard(int number, Map<String, dynamic> task) {
  final passed = task['pass'] == 1;
  final clue = _text(task['clue_text']);
  final options = ((task['options'] as List?) ?? const []).cast<Map<String, dynamic>>();
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: passed ? Pal.moss : Pal.cinnabar, shape: BoxShape.circle),
          child: passed
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_text(task['type_name'])}・${passed ? '已通過' : '未通過'}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: passed ? Pal.moss : Pal.inkSoft)),
            const SizedBox(height: 2),
            Text(_text(task['task_describe']), style: const TextStyle(color: Pal.ink, height: 1.4)),
            if (clue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('線索：$clue', style: const TextStyle(fontSize: 12, color: Pal.inkSoft)),
              ),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${_text(option['option_key'])}. ${_text(option['option_text'])}',
                    style: const TextStyle(fontSize: 12, color: Pal.inkSoft)),
              ),
          ]),
        ),
      ]),
    ),
  );
}
