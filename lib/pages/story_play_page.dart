import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/story_api.dart';
import '../block/navigationbar.dart';
import '../block/topbar.dart';
import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../core/app_text_styles.dart';
import '../core/bgm_service.dart';

const Color _pageColor = AppColors.background;
const Color _topColor = AppColors.paper;
const Color _darkText = AppColors.textPrimary;

const Color _skipStart = Color(0x66CBB57C);
const Color _skipEnd = Color(0x55AA9038);
const Color _skipBorder = Color(0xB8E3D1A4);

const Color _storyRed = AppColors.primaryAccent;

/// 劇情播放頁：一次一句，NPC 唸出台詞，點對話框看下一句，右上可跳過。
/// - 前傳：[generatedScript] 的劇本前傳與第一關開場白，播完進地圖頁
/// - 破關劇情：[lines] 直接給台詞，播完或跳過時呼叫 [onFinish]
class StoryPage extends StatefulWidget {
  final Map<String, dynamic>? generatedScript;

  /// 要播的台詞；有給就不看 [generatedScript]
  final List<StoryLine>? lines;

  final int? locationCurrent;
  final int? locationTotal;
  final int? postcardCurrent;
  final int? postcardTotal;

  /// 播完或跳過時的回呼；有給時不顯示導覽列
  final VoidCallback? onFinish;

  const StoryPage({
    super.key,
    this.generatedScript,
    this.lines,
    this.locationCurrent,
    this.locationTotal,
    this.postcardCurrent,
    this.postcardTotal,
    this.onFinish,
  });

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;

  static const double maxScale = 1.15;
  static const double topSpacePercent = 0.05;

  /// 語音同時準備的句數
  static const int voiceWorkers = 3;

  /// 單句語音的等待上限，逾時該句只顯示文字
  static const Duration voiceTimeout = Duration(seconds: 45);

  final AudioPlayer _npcAudioPlayer = AudioPlayer();
  StreamSubscription<void>? _completeSub;

  bool _isSpeaking = false;
  bool _isPreparing = true;
  bool _isDisposed = false;
  bool _isFinished = false;
  bool _advancing = false;
  String? _npcAvatar;
  String _loadingText = '正在準備劇情資訊…';

  double _voiceProgress = 0.0;

  int currentIndex = 1;
  int storyIndex = 0;

  bool skipHovering = false;
  bool skipPressing = false;

  final math.Random _random = math.Random();

  late String backgroundUrl;

  List<StoryLine> _storyLines = [];

  static const List<String> backgroundImages = [
    'https://images.pexels.com/photos/156934/pexels-photo-156934.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=1200&w=800',
    'https://images.pexels.com/photos/417173/pexels-photo-417173.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=1200&w=800',
    'https://images.pexels.com/photos/2212890/pexels-photo-2212890.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=1200&w=800',
  ];

  Map<String, dynamic>? get _scriptData {
    final dynamic data = widget.generatedScript?['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  List<Map<String, dynamic>> get _nodes {
    final dynamic nodes = _scriptData?['nodes'];

    if (nodes is! List) {
      return [];
    }

    return nodes
        .whereType<Map>()
        .map((node) => Map<String, dynamic>.from(node))
        .toList()
      ..sort((a, b) {
        final int orderA =
            int.tryParse((a['node_order'] ?? a['order'])?.toString() ?? '') ??
            0;

        final int orderB =
            int.tryParse((b['node_order'] ?? b['order'])?.toString() ?? '') ??
            0;

        return orderA.compareTo(orderB);
      });
  }

  Map<String, dynamic>? get _npc {
    final dynamic npc = _scriptData?['npc'];

    return npc is Map ? Map<String, dynamic>.from(npc) : null;
  }

  String? get _npcSpeaker {
    final String name = _npc?['name']?.toString().trim() ?? '';

    return name.isNotEmpty ? name : null;
  }

  String? get _npcVoice {
    final String voice = _npc?['voice']?.toString().trim() ?? '';

    return voice.isNotEmpty ? voice : null;
  }

  int get _locationCurrent => widget.locationCurrent ?? 0;
  int get _locationTotal => widget.locationTotal ?? _nodes.length;
  int get _postcardCurrent => widget.postcardCurrent ?? 0;
  int get _postcardTotal => widget.postcardTotal ?? _nodes.length;

  /// 單一關卡指定欄位的台詞，說話者優先用該關 NPC
  List<StoryLine> _nodeLines(Map<String, dynamic> node, List<String> keys) {
    final String npc = node['npc_name']?.toString().trim() ?? '';
    final String? name = npc.isNotEmpty ? npc : _npcSpeaker;
    final List<StoryLine> result = [];

    for (final String key in keys) {
      final String text = node[key]?.toString() ?? '';

      if (text.trim().isEmpty) continue;

      result.addAll(
        splitStoryLines(
          text,
          speaker: name ?? 'NPC',
          voice: _npcVoice,
          npcName: name,
        ),
      );
    }

    return result;
  }

  /// 前傳：劇本前傳（旁白）＋第一關開場白
  List<StoryLine> _buildPrologueLines() {
    final String preface = _scriptData?['preface']?.toString() ?? '';

    final List<StoryLine> result = splitStoryLines(
      preface,
      speaker: '旁白',
      voice: _npcVoice,
      npcName: _npcSpeaker,
    );

    final List<Map<String, dynamic>> nodes = _nodes;

    if (nodes.isNotEmpty) {
      result.addAll(_nodeLines(nodes.first, ['opening']));
    }

    return result;
  }

  /// 之後關卡會用到的台詞，背景預先準備語音
  List<StoryLine> _buildExtraLines() {
    final List<Map<String, dynamic>> nodes = _nodes;
    final List<StoryLine> extra = [];

    for (int i = 0; i < nodes.length; i++) {
      extra.addAll(
        _nodeLines(
          nodes[i],
          i == 0
              ? ['success_text', 'success']
              : ['opening', 'success_text', 'success'],
        ),
      );
    }

    return extra;
  }

  /// 把一句台詞轉成語音檔；失敗或逾時回傳 null
  Future<String?> _prepareVoice(
    StoryLine line, {
    void Function(String status)? onStatus,
  }) async {
    try {
      return await StoryApi.prepareNpcVoice(
        text: line.text,
        voice: line.voice,
        npcName: line.npcName,
        onStatus: (String status) => onStatus?.call(status),
      ).timeout(voiceTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> _prepareAllVoices() async {
    final List<StoryLine> lines = widget.lines ?? _buildPrologueLines();

    if (lines.isEmpty) {
      setState(() {
        _storyLines = [const StoryLine(name: '旁白', text: '目前尚未取得劇本內容。')];
        _voiceProgress = 1.0;
        _isPreparing = false;
      });

      return;
    }

    for (final String url
        in lines
            .map((line) => line.backgroundUrl)
            .whereType<String>()
            .toSet()) {
      precacheImage(
        NetworkImage(url),
        context,
        onError: (error, stackTrace) {},
      );
    }

    setState(() {
      _voiceProgress = 0.0;
      _loadingText = '正在建立劇情語音…';
    });

    final List<StoryLine> preparedLines = List.of(lines);
    int next = 0;
    int done = 0;

    Future<void> worker() async {
      while (next < lines.length && !_isDisposed) {
        final int i = next++;

        final String? path = await _prepareVoice(
          lines[i],
          onStatus: (status) {
            if (mounted && !_isDisposed) {
              setState(() {
                _loadingText = status;
              });
            }
          },
        );

        if (path != null) {
          preparedLines[i] = lines[i].copyWith(audioPath: path);
        }

        done++;

        if (mounted) {
          setState(() {
            _voiceProgress = done / lines.length;
          });
        }
      }
    }

    await Future.wait([
      for (int k = 0; k < math.min(voiceWorkers, lines.length); k++) worker(),
    ]);

    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      _voiceProgress = 1.0;
      _storyLines = preparedLines;
      storyIndex = 0;
      _isPreparing = false;
    });

    if (widget.lines == null) {
      _preloadVoices(_buildExtraLines());
    }

    await _playCurrentVoice();
  }

  /// 背景預先準備後續關卡的語音，不阻擋劇情播放
  Future<void> _preloadVoices(List<StoryLine> extra) async {
    int next = 0;

    Future<void> worker() async {
      while (next < extra.length) {
        await _prepareVoice(extra[next++]);
      }
    }

    await Future.wait([
      for (int k = 0; k < math.min(voiceWorkers, extra.length); k++) worker(),
    ]);
  }

  Future<void> _playCurrentVoice() async {
    if (_isDisposed ||
        _storyLines.isEmpty ||
        storyIndex < 0 ||
        storyIndex >= _storyLines.length) {
      return;
    }

    final String audioPath = _storyLines[storyIndex].audioPath?.trim() ?? '';

    if (audioPath.isEmpty) {
      BgmService.instance.unduck();
      return;
    }

    try {
      await _npcAudioPlayer.stop();

      BgmService.instance.duck();

      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }

      await _npcAudioPlayer.play(DeviceFileSource(audioPath));
    } catch (_) {
      BgmService.instance.unduck();

      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  /// 停止配音；[restoreMusic] 為 false 時保持背景音樂壓低（接著要播下一句）
  Future<void> _stopNpcVoice({bool restoreMusic = true}) async {
    try {
      await _npcAudioPlayer.stop();
    } catch (_) {}

    if (restoreMusic) {
      BgmService.instance.unduck();
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    } else {
      _isSpeaking = false;
    }
  }

  Future<void> nextStory() async {
    if (_isPreparing || _storyLines.isEmpty || _advancing) {
      return;
    }

    _advancing = true;

    try {
      await _stopNpcVoice(restoreMusic: false);

      if (!mounted) {
        return;
      }

      if (storyIndex + 1 >= _storyLines.length) {
        finishStory();
        return;
      }

      setState(() {
        storyIndex++;
      });

      await _playCurrentVoice();
    } finally {
      _advancing = false;
    }
  }

  Future<void> skipStory() async {
    await _stopNpcVoice();
    finishStory();
  }

  void finishStory() {
    if (!mounted || _isFinished) {
      return;
    }

    _isFinished = true;

    BgmService.instance.unduck();

    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }

    Navigator.pushReplacementNamed(context, '/story-map');
  }

  /// 讀取畫面和沒帶 NPC 圖的台詞用的 NPC 圖：台詞帶的（那一站的 NPC）優先，再來是劇本的 NPC，
  /// 都沒有才用上次確認劇本時記下的（用配對碼加入的隊友、重裝 App 後沒有記錄，會是預設圖）
  Future<void> _initNpcAvatar() async {
    final String fromLines = (widget.lines ?? const <StoryLine>[])
        .map((line) => line.npcAvatarUrl?.trim() ?? '')
        .firstWhere((url) => url.isNotEmpty, orElse: () => '');
    final String fromScript = _npc?['avatar_url']?.toString().trim() ?? '';
    final String? avatar = fromLines.isNotEmpty
        ? fromLines
        : fromScript.isNotEmpty
        ? fromScript
        : await StoryApi.getNpcAvatar();

    if (mounted && avatar != null && avatar.isNotEmpty) {
      setState(() {
        _npcAvatar = avatar;
      });
    }
  }

  double _getScale(double width, double height) {
    return AppResponsive.scale(
      availableWidth: width,
      availableHeight: height,
      designWidth: designWidth,
      designHeight: designHeight,
      max: maxScale,
    );
  }

  @override
  void initState() {
    super.initState();

    backgroundUrl = backgroundImages[_random.nextInt(backgroundImages.length)];

    _completeSub = _npcAudioPlayer.onPlayerComplete.listen((_) {
      if (!mounted || _isDisposed) {
        return;
      }

      BgmService.instance.unduck();

      setState(() {
        _isSpeaking = false;
      });
    });

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _topColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initNpcAvatar();
      _prepareAllVoices();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    _completeSub?.cancel();
    _npcAudioPlayer.stop();
    _npcAudioPlayer.dispose();

    BgmService.instance.unduck();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreparing) {
      return _StoryLoadingPage(
        text: _loadingText,
        progress: _voiceProgress,
        npcAvatar: _npcAvatar,
      );
    }

    final StoryLine story = _storyLines.isNotEmpty
        ? _storyLines[storyIndex.clamp(0, _storyLines.length - 1)]
        : const StoryLine(name: '旁白', text: '目前尚未取得劇本內容。');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _topColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pageColor,
        extendBody: true,
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;
            final double scale = _getScale(screenWidth, screenHeight);
            final double topOffset = screenHeight * topSpacePercent;
            final double actualTopBarWidth = topBarDesignWidth * scale;
            final double actualTopBarHeight = topBarDesignHeight * scale;

            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _BackgroundImage(
                    imageUrl: story.backgroundUrl ?? backgroundUrl,
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Color(0x55000000)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topOffset + actualTopBarHeight,
                  child: const ColoredBox(color: _topColor),
                ),
                Positioned(
                  left: 0,
                  top: topOffset,
                  width: screenWidth,
                  height: actualTopBarHeight,
                  child: Center(
                    child: SizedBox(
                      width: actualTopBarWidth,
                      height: actualTopBarHeight,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: topBarDesignWidth,
                          height: topBarDesignHeight,
                          child: TopBar(
                            locationCurrent: _locationCurrent,
                            locationTotal: _locationTotal,
                            postcardCurrent: _postcardCurrent,
                            postcardTotal: _postcardTotal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: topOffset + actualTopBarHeight + (6 * scale),
                  right: math.max(
                    10 * scale,
                    (screenWidth - actualTopBarWidth) / 2 + (10 * scale),
                  ),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: _SkipStoryButton(
                      hovering: skipHovering,
                      pressing: skipPressing,
                      onHoverEnter: () {
                        setState(() {
                          skipHovering = true;
                        });
                      },
                      onHoverExit: () {
                        setState(() {
                          skipHovering = false;
                        });
                      },
                      onPress: () {
                        setState(() {
                          skipPressing = true;
                        });
                      },
                      onRelease: () {
                        setState(() {
                          skipPressing = false;
                        });
                      },
                      onTap: skipStory,
                    ),
                  ),
                ),
                _GameViewport(
                  designWidth: designWidth,
                  designHeight: designHeight,
                  scale: scale,
                  topOffset: topOffset,
                  child: _StoryGameContent(
                    story: story,
                    onNextStory: nextStory,
                    isSpeaking: _isSpeaking,
                    isLast: storyIndex >= _storyLines.length - 1,
                    npcAvatar: story.npcAvatarUrl ?? _npcAvatar,
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: widget.onFinish == null
            ? AppNavigationBar(currentIndex: currentIndex)
            : null,
      ),
    );
  }
}

class _StoryLoadingPage extends StatefulWidget {
  final String text;
  final double progress;
  final String? npcAvatar;

  const _StoryLoadingPage({
    required this.text,
    required this.progress,
    this.npcAvatar,
  });
  @override
  State<_StoryLoadingPage> createState() => _StoryLoadingPageState();
}

class _StoryLoadingPageState extends State<_StoryLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Tween<double> _tween = Tween<double>();

  double _displayProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _displayProgress = widget.progress.clamp(0.0, 1.0);
    _tween.begin = _displayProgress;
    _tween.end = _displayProgress;

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 450),
        )..addListener(() {
          if (!mounted) return;

          setState(() {
            _displayProgress = _tween.transform(
              Curves.easeOutCubic.transform(_controller.value),
            );
          });
        });
  }

  @override
  void didUpdateWidget(covariant _StoryLoadingPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.progress != oldWidget.progress) {
      _tween.begin = _displayProgress;
      _tween.end = widget.progress.clamp(0.0, 1.0);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _displayProgress.clamp(0.0, 1.0);
    final int percent = (progress * 100).round().clamp(0, 100);

    return Scaffold(
      backgroundColor: _pageColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'img/background_papper.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(color: _pageColor);
              },
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.30)),
          ),
          Center(
            child: SizedBox(
              width: 330,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 245,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'img/story_box.png',
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: _topColor.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _storyRed,
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 18,
                          right: 25,
                          child: _NpcImage(
                            url: widget.npcAvatar,
                            width: 145,
                            height: 205,
                          ),
                        ),
                        Positioned(
                          left: 24,
                          top: 30,
                          right: 145,
                          child: Text(
                            '劇情準備中',
                            style: AppTextStyles.titleMediumBold.copyWith(
                              color: _storyRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '$percent%',
                    style: AppTextStyles.titleMediumBold.copyWith(
                      color: _topColor,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 22,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _skipBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [_skipStart, _skipEnd, _storyRed],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.text,
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: _topColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _topColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameViewport extends StatelessWidget {
  final double designWidth;
  final double designHeight;
  final double scale;
  final double topOffset;
  final Widget child;

  const _GameViewport({
    required this.designWidth,
    required this.designHeight,
    required this.scale,
    required this.topOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double viewportWidth = designWidth * scale;
    final double viewportHeight = designHeight * scale;

    return Positioned(
      left: 0,
      right: 0,
      top: topOffset,
      bottom: 0,
      child: Center(
        child: SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.center,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryGameContent extends StatelessWidget {
  final StoryLine story;
  final VoidCallback onNextStory;
  final bool isSpeaking;
  final bool isLast;
  final String? npcAvatar;

  const _StoryGameContent({
    required this.story,
    required this.onNextStory,
    required this.isSpeaking,
    required this.isLast,
    this.npcAvatar,
  });

  @override
  Widget build(BuildContext context) {
    const double storyBottom = 78.0;
    const double navigationReserve = 76.0;

    return SizedBox(
      width: 360,
      height: 640,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            bottom: storyBottom + navigationReserve + 10,
            child: IgnorePointer(
              child: _NpcImage(url: npcAvatar, width: 200, height: 285),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: storyBottom - 15,
            child: _StoryDialog(
              story: story,
              onTap: onNextStory,
              isSpeaking: isSpeaking,
              isLast: isLast,
            ),
          ),
        ],
      ),
    );
  }
}

class _NpcImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const _NpcImage({
    required this.url,
    required this.width,
    required this.height,
  });

  Widget _fallback() {
    return Image.asset(
      'img/npc_.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(width: width, height: height);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String link = url?.trim() ?? '';

    if (link.isEmpty) {
      return _fallback();
    }

    return Image.network(
      link,
      width: width,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, child, loadingProgress) {
        return loadingProgress == null
            ? child
            : SizedBox(width: width, height: height);
      },
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final String imageUrl;

  const _BackgroundImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const ColoredBox(
            color: _pageColor,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _storyRed,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'img/background_papper.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}

class _SkipStoryButton extends StatelessWidget {
  final bool hovering;
  final bool pressing;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final VoidCallback onPress;
  final VoidCallback onRelease;
  final VoidCallback onTap;

  const _SkipStoryButton({
    required this.hovering,
    required this.pressing,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onPress,
    required this.onRelease,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonScale = pressing
        ? 0.96
        : hovering
        ? 1.06
        : 1.0;

    return MouseRegion(
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      child: GestureDetector(
        onTap: onTap,
        onTapDown: (_) => onPress(),
        onTapUp: (_) => onRelease(),
        onTapCancel: onRelease,
        child: AnimatedScale(
          scale: buttonScale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 128,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [_skipStart, _skipEnd],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _skipBorder, width: 1.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '跳過劇情  >>',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: _topColor,
                    height: 1,
                    shadows: const [
                      Shadow(
                        color: Color(0x55000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryDialog extends StatelessWidget {
  final StoryLine story;
  final VoidCallback onTap;
  final bool isSpeaking;
  final bool isLast;

  const _StoryDialog({
    required this.story,
    required this.onTap,
    required this.isSpeaking,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'img/story_box.png',
                  width: double.infinity,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8DFC9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF806C54)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 51, 15, 31),
                child: Text(
                  story.text,
                  softWrap: true,
                  style: AppTextStyles.bodyCompactBold.copyWith(
                    color: _darkText,
                    height: 1.45,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 0,
                child: SizedBox(
                  width: 104,
                  height: 42,
                  child: Image.asset(
                    'img/story_name.png',
                    width: 104,
                    height: 42,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 104,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _storyRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 0,
                width: 104,
                height: 42,
                child: Center(
                  child: Text(
                    story.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMediumBold.copyWith(
                      color: _topColor,
                      height: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 13,
                bottom: 7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSpeaking)
                      const Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: SizedBox(
                          width: 9,
                          height: 9,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF806C54),
                          ),
                        ),
                      ),
                    Text(
                      isSpeaking
                          ? '播放中'
                          : isLast
                          ? '點擊結束'
                          : '點擊繼續',
                      style: AppTextStyles.microBold.copyWith(
                        color: const Color(0xFF806C54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 劇情的一句話：name 是名牌，text 是台詞，voice／npcName 決定配音，
/// backgroundUrl 是這句的背景圖，npcAvatarUrl 是這句站在右下的 NPC 圖（破關、開場劇情帶那一站的 NPC），
/// audioPath 是準備好的語音檔
class StoryLine {
  final String name;
  final String text;
  final String? voice;
  final String? npcName;
  final String? backgroundUrl;
  final String? npcAvatarUrl;
  final String? audioPath;

  const StoryLine({
    required this.name,
    required this.text,
    this.voice,
    this.npcName,
    this.backgroundUrl,
    this.npcAvatarUrl,
    this.audioPath,
  });

  StoryLine copyWith({
    String? name,
    String? text,
    String? voice,
    String? npcName,
    String? backgroundUrl,
    String? npcAvatarUrl,
    String? audioPath,
  }) {
    return StoryLine(
      name: name ?? this.name,
      text: text ?? this.text,
      voice: voice ?? this.voice,
      npcName: npcName ?? this.npcName,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      npcAvatarUrl: npcAvatarUrl ?? this.npcAvatarUrl,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}

/// 一句話：到。！？為止，後面緊接的引號、括號算同一句
final RegExp _sentencePattern = RegExp(r'[^。！？!?]+(?:[。！？!?]+[」』”’）)]*)?');

/// 一行開頭寫明說話者，例如「薯光：」「薯光說：」
final RegExp _speakerPattern = RegExp(r'^\s*([^\s：:，,。！？!?「」]{1,8}?)說?[：:]\s*');

final RegExp _commaPattern = RegExp(r'[，,]');

/// 一句內逗號超過 4 個時，每 4 個逗號切成一句
List<String> _splitByComma(String sentence) {
  final List<String> parts = [];
  String rest = sentence;

  while (true) {
    final List<RegExpMatch> commas = _commaPattern.allMatches(rest).toList();

    if (commas.length <= 4) break;

    final int cut = commas[3].end;

    parts.add(rest.substring(0, cut).trim());
    rest = rest.substring(cut).trim();
  }

  if (rest.isNotEmpty) parts.add(rest);

  return parts;
}

/// 把一段劇情拆成一句一句；換行也算一句結束，
/// 開頭寫明「某某：」的那行算某某說的，其他算 [speaker] 說的
List<StoryLine> splitStoryLines(
  String text, {
  required String speaker,
  String? voice,
  String? npcName,
  String? backgroundUrl,
  String? npcAvatarUrl,
}) {
  final List<StoryLine> lines = [];

  for (String paragraph in text.split('\n')) {
    String name = speaker;

    final RegExpMatch? said = _speakerPattern.firstMatch(paragraph);

    if (said != null) {
      name = said.group(1)!;
      paragraph = paragraph.substring(said.end);
    }

    for (final RegExpMatch match in _sentencePattern.allMatches(paragraph)) {
      final String sentence = match.group(0)!.trim();

      for (final String part in _splitByComma(sentence)) {
        if (part.isNotEmpty) {
          lines.add(
            StoryLine(
              name: name,
              text: part,
              voice: voice,
              npcName: npcName,
              backgroundUrl: backgroundUrl,
              npcAvatarUrl: npcAvatarUrl,
            ),
          );
        }
      }
    }
  }

  return lines;
}
