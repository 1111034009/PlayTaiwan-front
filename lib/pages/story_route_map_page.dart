import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../block/ai_talk_button.dart';
import '../block/navigationbar.dart';
import '../block/topbar.dart';
import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../core/app_text_styles.dart';
import '../route_map/api.dart';
import '../route_map/models.dart';
import '../route_map/pages/treasure_map.dart';
import '../route_map/theme.dart';
import 'story_play_page.dart';
import 'story_postcard_page.dart';
import 'story_task_page.dart';

/// 地圖頁（真的地圖）：正在玩的劇本的藏寶圖，一關一關解開。
/// 上列和下面的導覽列是這個 App 自己的；中間的地圖和功能（迷霧、路線、景點卡片、順路、提醒、隊友位置）在 lib/route_map，
/// 是從路線展示專案搬過來的 [TreasureMap]。
///
/// 玩的是哪一個劇本：後端說正在進行的那一個（GET /api/Story/CurrentPlaying）；
/// 沒有進行中的就用自己最新的一個劇本，一個都沒有才顯示提示
class StoryRouteMapPage extends StatefulWidget {
  const StoryRouteMapPage({super.key});

  @override
  State<StoryRouteMapPage> createState() => _StoryRouteMapPageState();
}

class _StoryRouteMapPageState extends State<StoryRouteMapPage> {
  static const double _designWidth = 360.0;
  static const double _designHeight = 640.0;
  static const double _maxScale = 1.15;
  static const double _topSpacePercent = 0.05;

  /// 上列的「明信片收集」：這份劇本拿到幾張、總共可以拿幾張，後端跟著地圖進度一起給
  int _postcardCurrent = 0;
  int _postcardTotal = 0;

  RouteStory? _story;
  bool _loading = true;
  String? _message;

  /// 上列的「地點探索度」：破了幾關、總共幾關，地圖載入和破關時會更新
  int _cleared = 0;
  int _total = 0;

  /// 做任務時在拍照任務交的照片，key 是節點代號：那一關破關時拿來做明信片
  final Map<int, XFile> _taskPhotos = {};

  /// 破關的劇情和明信片一關一關來：上一關的還開著時又破一關（例如隊友做完的），等它關掉再輪到下一關
  Future<void> _afterClear = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final stories = (await Api.instance.get('/api/Route/Stories') as List)
          .cast<Map<String, dynamic>>()
          .map(RouteStory.fromJson)
          .toList();

      int? playingId;
      try {
        final playing = await Api.instance.get('/api/Story/CurrentPlaying') as Map<String, dynamic>?;
        playingId = (playing?['story_id'] as num?)?.toInt();
      } catch (_) {
        // 查不到正在進行的劇本就用最新的那一個
      }

      if (!mounted) return;
      setState(() {
        _story = stories.where((s) => s.storyId == playingId).firstOrNull ?? stories.firstOrNull;
        _message = _story == null ? '還沒有劇本，先到首頁開一個劇本吧。' : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        // 跟其他頁一樣讓內容延伸到導覽列後面（導覽列上緣是透明的弧形）；地圖頁自己會讓出下面的空間
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final scale = AppResponsive.scale(
              availableWidth: constraints.maxWidth,
              availableHeight: constraints.maxHeight,
              designWidth: _designWidth,
              designHeight: _designHeight,
              max: _maxScale,
            );
            final topOffset = constraints.maxHeight * _topSpacePercent;
            final topBarWidth = topBarDesignWidth * scale;
            final topBarHeight = topBarDesignHeight * scale;

            return Column(children: [
              // 上列：跟原本的地圖頁同一個排法
              Container(
                height: topOffset + topBarHeight,
                width: double.infinity,
                color: AppColors.paper,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: topBarWidth,
                  height: topBarHeight,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: topBarDesignWidth,
                      height: topBarDesignHeight,
                      child: TopBar(
                        locationCurrent: _cleared,
                        locationTotal: _total,
                        postcardCurrent: _postcardCurrent,
                        postcardTotal: _postcardTotal,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: story == null
                    ? _placeholder()
                    // 地圖頁有自己的配色（羊皮紙、朱砂紅），字型用這個 App 的
                    : Theme(
                        data: buildTheme(fontFamily: AppTextStyles.body.fontFamily),
                        child: TreasureMap(
                          key: ValueKey(story.storyId),
                          story: story,
                          embedded: true,
                          // 比賽展示用：面板上多了「模擬沿路線走」「故意走偏」「模擬隊友」，模擬的位置會當成真的定位送給後端。
                          // 正式上線前把這一行拿掉
                          demoTools: true,
                          // 右下角那隻貓當地圖上的 NPC：提醒的泡泡從牠旁邊跳出來，點牠一樣是開 AI 對話
                          npcAvatar: const AiTalkButton(),
                          // 「做任務」：開這一關的答題頁（配色跟地圖頁同一套），破關了它會自己關掉。
                          // 關掉回來之後地圖會自己更新進度；這一次在拍照任務交的照片先留著，破關的明信片要用
                          onDoTasks: (node, myLocation) async {
                            final result = await Navigator.of(context).push(MaterialPageRoute<StoryTaskResult>(
                              builder: (_) => Theme(
                                data: buildTheme(fontFamily: AppTextStyles.body.fontFamily),
                                child: StoryTaskPage(node: node, myLocation: myLocation),
                              ),
                            ));
                            final photo = result?.photo;
                            if (photo != null) _taskPhotos[node.nodeId] = photo;
                          },
                          // 破關了（地圖跟後端確認過這一關過了）：不用按什麼，先播破關劇情，播完自動跳出這一關的明信片
                          onStageCleared: (node, next) {
                            _afterClear = _afterClear.then((_) async {
                              // 劇情或明信片哪一個沒做成，都不影響另一個和之後的
                              try {
                                if (mounted) await _playStageStory(node, next);
                              } catch (_) {}
                              try {
                                if (mounted) await _makePostcard(story, node, _taskPhotos.remove(node.nodeId));
                              } catch (_) {}
                            });
                          },
                          onPostcards: (have, total) {
                            if (mounted && (have != _postcardCurrent || total != _postcardTotal)) {
                              setState(() {
                                _postcardCurrent = have;
                                _postcardTotal = total;
                              });
                            }
                          },
                          onProgress: (cleared, total) {
                            if (mounted && (cleared != _cleared || total != _total)) {
                              setState(() {
                                _cleared = cleared;
                                _total = total;
                              });
                            }
                          },
                        ),
                      ),
              ),
            ]);
          },
        ),
        bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
      ),
    );
  }

  /// 破關劇情：剛破的這一關的完成劇情，接著跟著解鎖的下一關的開場白，在劇情頁一句一句播、NPC 唸出來。
  /// - 完成劇情：GET /api/Task/Node/{這一關} 的 node.success_text，由這一站的 NPC（npc）說
  /// - 開場白：GET /api/Map/Node/{下一關}/Interact 的 npc_dialogue（剛解鎖、還沒抵達也拿得到），由劇本的 NPC 說
  /// 背景是那一站的情境圖（Interact 的 scene_image_url）：這一關抵達過是景點照片，下一關還沒到是迷霧圖。
  /// 最後一關破關就只有完成劇情；兩段都拿不到就不播
  Future<void> _playStageStory(MapNode cleared, MapNode? next) async {
    final responses = await Future.wait([
      _tryGet('/api/Task/Node/${cleared.nodeId}'),
      _tryGet('/api/Map/Node/${cleared.nodeId}/Interact'),
      if (next != null) _tryGet('/api/Map/Node/${next.nodeId}/Interact'),
    ]);
    final play = responses[0];
    final clearedScene = responses[1];
    final nextScene = next == null ? null : responses[2];
    final npc = play?['npc'] as Map<String, dynamic>?;

    final lines = [
      ...splitStoryLines(
        _text((play?['node'] as Map<String, dynamic>?)?['success_text']) ?? '',
        speaker: _text(npc?['npc_name']) ?? '旁白',
        voice: _text(npc?['npc_voice']),
        backgroundUrl: _text(clearedScene?['scene_image_url']),
      ),
      ...splitStoryLines(
        _text(nextScene?['npc_dialogue']) ?? '',
        speaker: _text(nextScene?['npc_name']) ?? '旁白',
        voice: _text(nextScene?['npc_voice']),
        backgroundUrl: _text(nextScene?['scene_image_url']),
      ),
    ];
    if (lines.isEmpty || !mounted) return;

    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (page) => StoryPage(
        lines: lines,
        locationCurrent: _cleared,
        locationTotal: _total,
        postcardCurrent: _postcardCurrent,
        postcardTotal: _postcardTotal,
        onFinish: () => Navigator.of(page).pop(),
      ),
    ));
  }

  /// 拿不到（例如還沒抵達、連不到後端）就是 null
  static Future<Map<String, dynamic>?> _tryGet(String path) async {
    try {
      return await Api.instance.get(path) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// 後端的文字欄位：去掉頭尾空白，空的當成沒有
  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  /// 破關時自動跳出來的明信片：用這一關拍照任務交的照片；沒有的話請玩家拍一張或從相簿選（也可以先不要）。
  /// 照片和這一關的景點名稱、劇本、節點交給明信片頁去做（POST /api/PostcardCatalog/GenerateAi），
  /// 做好之後後端算的明信片張數會加一
  Future<void> _makePostcard(RouteStory story, MapNode node, XFile? photo) async {
    photo ??= await _pickPostcardPhoto(node);
    if (photo == null || !mounted) return;

    final Uint8List bytes;
    try {
      bytes = await photo.readAsBytes();
    } catch (e) {
      if (mounted) _snack('讀不到照片：$e');
      return;
    }
    if (!mounted) return;

    // 後端看副檔名認圖片，有些瀏覽器給的檔名沒有副檔名
    final name = photo.name.contains('.') ? photo.name : '${photo.name.isEmpty ? 'photo' : photo.name}.jpg';
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (page) => StoryPostcardPage(
        imageBytes: bytes,
        imageName: name,
        spotName: node.label,
        storyId: story.storyId,
        nodeId: node.nodeId,
        onNext: () => Navigator.of(page).pop(),
      ),
    ));
  }

  /// 這一關沒有拍照任務的照片可以用：請玩家現場拍一張，或從相簿選；按「先不要」就不做明信片
  Future<XFile?> _pickPostcardPhoto(MapNode node) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('做一張這一關的明信片'),
        content: Text('拍一張「${node.label}」的照片，或從相簿選一張，做成這一關的專屬明信片。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('先不要')),
          TextButton(onPressed: () => Navigator.of(dialog).pop(ImageSource.gallery), child: const Text('從相簿選')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(ImageSource.camera), child: const Text('拍照')),
        ],
      ),
    );
    if (source == null) return null;
    try {
      return await ImagePicker().pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    } catch (e) {
      if (mounted) _snack('開不了相機或相簿：$e');
      return null;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// 還在找劇本，或沒有劇本、連不到後端
  Widget _placeholder() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_message ?? '', textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.paper)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('重試')),
        ]),
      ),
    );
  }
}
