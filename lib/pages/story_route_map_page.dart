import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // 明信片的數字跟原本的地圖頁一樣先放固定的：後端還沒有「這個劇本收集了幾張」的 API
  static const int _postcardCurrent = 1;
  static const int _postcardTotal = 10;

  RouteStory? _story;
  bool _loading = true;
  String? _message;

  /// 上列的「地點探索度」：破了幾關、總共幾關，地圖載入和破關時會更新
  int _cleared = 0;
  int _total = 0;

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
                          // 右下角那隻貓當地圖上的 NPC：提醒的泡泡從牠旁邊跳出來，點牠一樣是開 AI 對話
                          npcAvatar: const AiTalkButton(),
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
