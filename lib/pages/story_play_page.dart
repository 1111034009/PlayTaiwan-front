import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../api/story_api.dart';
import '../block/navigationbar.dart';
import '../block/topbar.dart';

const Color _pageColor = AppColors.background;
const Color _topColor = AppColors.paper;
const Color _darkText = AppColors.textPrimary;

const Color _skipStart = Color(0x66CBB57C);
const Color _skipEnd = Color(0x55AA9038);
const Color _skipBorder = Color(0xB8E3D1A4);

const Color _storyRed = AppColors.primaryAccent;

/// 劇情播放頁：一次一句，NPC 把台詞唸出來，點對話框看下一句，右上可以跳過。
/// - 前傳：確認劇本、隊伍出發後播。[generatedScript] 是劇本詳情（{'story_id', 'data'}），
///   播劇本前傳和第一關的開場白，播完進地圖頁
/// - 破關劇情：地圖頁直接給要播的台詞（[lines]），播完或跳過時叫 [onFinish]
class StoryPage extends StatefulWidget {
  final Map<String, dynamic>? generatedScript;

  /// 要播的台詞；有給就不看 [generatedScript]
  final List<StoryLine>? lines;

  /// 上列的地點探索度、明信片收集；沒給就用劇本的站數算（剛開始都是 0）
  final int? locationCurrent;
  final int? locationTotal;
  final int? postcardCurrent;
  final int? postcardTotal;

  /// 播完或跳過時；沒給就進地圖頁。
  /// 有給的時候不顯示下面的導覽列：這一頁是疊在地圖頁上面的，從這裡切去別頁會留下底下那一頁
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

  /// 語音同時準備幾句
  static const int voiceWorkers = 3;

  final AudioPlayer _npcAudioPlayer = AudioPlayer();

  bool _isSpeaking = false;
  bool _isPreparing = true;
  bool _isDisposed = false;
  bool _isFinished = false;

  String _loadingText = '正在準備劇情資訊…';

  double _voiceProgress = 0.0;

  int currentIndex = 1;

  int storyIndex = 0;

  bool skipHovering = false;
  bool skipPressing = false;

  final math.Random _random = math.Random();

  /// 台詞沒有指定背景圖時用的背景
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

  String get _npcName {
    final String name = _npc?['name']?.toString().trim() ?? '';

    return name.isNotEmpty ? name : 'NPC';
  }

  /// 唸前傳的 NPC（劇本的 NPC）；沒有時後端用薯光
  String? get _npcSpeaker {
    final String name = _npc?['name']?.toString().trim() ?? '';

    return name.isNotEmpty ? name : null;
  }

  /// 劇本 NPC 的聲線；沒有時後端用預設聲線
  String? get _npcVoice {
    final String voice = _npc?['voice']?.toString().trim() ?? '';

    return voice.isNotEmpty ? voice : null;
  }

  int get _locationCurrent => widget.locationCurrent ?? 0;
  int get _locationTotal => widget.locationTotal ?? _nodes.length;
  int get _postcardCurrent => widget.postcardCurrent ?? 0;
  int get _postcardTotal => widget.postcardTotal ?? _nodes.length;

  /// 前傳要播的台詞：劇本前傳（旁白），接著第一關的開場白。
  /// 第一關一開始就解鎖了，所以開場白在這裡播；之後每破一關，地圖頁會播下一關的開場白
  List<StoryLine> _buildPrologueLines() {
    final String preface = _scriptData?['preface']?.toString() ?? '';

    final List<Map<String, dynamic>> nodes = _nodes;
    final Map<String, dynamic>? first = nodes.isEmpty ? null : nodes.first;
    final String firstNpc = first?['npc_name']?.toString().trim() ?? '';

    return [
      ...splitStoryLines(
        preface,
        speaker: '旁白',
        voice: _npcVoice,
        npcName: _npcSpeaker,
      ),
      if (first != null)
        ...splitStoryLines(
          first['opening']?.toString() ?? '',
          speaker: firstNpc.isNotEmpty ? firstNpc : _npcName,
          voice: _npcVoice,
          npcName: firstNpc.isNotEmpty ? firstNpc : _npcSpeaker,
        ),
    ];
  }

  /// 每一句先轉成語音（POST /api/Npc/Speak，排隊做好後下載）再開始播。幾句同時準備，
  /// 排隊時讀取畫面顯示「語音等待中／生成中」；哪一句沒做成，那一句就只顯示文字，不影響其他句
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

    // 台詞的背景圖先載好，換到下一段時才不會閃一下
    for (final String url
        in lines.map((line) => line.backgroundUrl).whereType<String>().toSet()) {
      precacheImage(NetworkImage(url), context, onError: (error, stackTrace) {});
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

        try {
          final String localPath = await StoryApi.prepareNpcVoice(
            text: lines[i].text,
            voice: lines[i].voice,
            npcName: lines[i].npcName,
            onStatus: (status) {
              if (mounted && !_isDisposed) {
                setState(() {
                  _loadingText = status;
                });
              }
            },
          );

          preparedLines[i] = lines[i].copyWith(audioPath: localPath);
        } catch (_) {
          // 這一句沒有語音，只顯示文字
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

    await _playCurrentVoice();
  }

  Future<void> _playCurrentVoice() async {
    if (_isDisposed ||
        _storyLines.isEmpty ||
        storyIndex < 0 ||
        storyIndex >= _storyLines.length) {
      return;
    }

    final StoryLine line = _storyLines[storyIndex];

    final String audioPath = line.audioPath?.trim() ?? '';

    if (audioPath.isEmpty) {
      return;
    }

    try {
      await _npcAudioPlayer.stop();

      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }

      await _npcAudioPlayer.play(DeviceFileSource(audioPath));
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  Future<void> _stopNpcVoice() async {
    try {
      await _npcAudioPlayer.stop();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    } else {
      _isSpeaking = false;
    }
  }

  Future<void> nextStory() async {
    if (_isPreparing || _storyLines.isEmpty) {
      return;
    }

    await _stopNpcVoice();

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
  }

  Future<void> skipStory() async {
    await _stopNpcVoice();
    finishStory();
  }

  void finishStory() {
    // 最後一句和跳過連按時只結束一次，不然會多關掉底下的頁面
    if (!mounted || _isFinished) {
      return;
    }

    _isFinished = true;

    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }

    Navigator.pushReplacementNamed(context, '/story-map');
  }

  void onNavigationTap(int index) {
    setState(() {
      currentIndex = index;
    });

    if (index == 0) {
      _stopNpcVoice();

      Navigator.pushReplacementNamed(context, '/home');
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

    _npcAudioPlayer.onPlayerComplete.listen((_) {
      if (!mounted || _isDisposed) {
        return;
      }

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

    // 第一個畫面出來之後才開始：要用 context 預先載背景圖
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepareAllVoices();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    _npcAudioPlayer.stop();
    _npcAudioPlayer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreparing) {
      return _StoryLoadingPage(text: _loadingText, progress: _voiceProgress);
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

  const _StoryLoadingPage({required this.text, required this.progress});

  @override
  State<_StoryLoadingPage> createState() => _StoryLoadingPageState();
}

class _StoryLoadingPageState extends State<_StoryLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _displayProgress = 0.0;

  @override
  void initState() {
    super.initState();

    _displayProgress = widget.progress.clamp(0.0, 1.0);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(covariant _StoryLoadingPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.progress != oldWidget.progress) {
      final double start = _displayProgress;
      final double end = widget.progress.clamp(0.0, 1.0);

      _controller.stop();
      _controller.reset();

      final Animation<double> animation = Tween<double>(begin: start, end: end)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );

      animation.addListener(() {
        if (!mounted) return;

        setState(() {
          _displayProgress = animation.value;
        });
      });

      _controller.forward();
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
            child: Container(color: Colors.black.withOpacity(0.30)),
          ),

          Center(
            child: SizedBox(
              width: 330,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // =========================
                  // 劇情框
                  // =========================
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
                                  color: _topColor.withOpacity(0.94),
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
                          child: Image.asset(
                            'img/npc_.png',
                            width: 145,
                            height: 205,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox(width: 145, height: 205);
                            },
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

                  // =========================
                  // 百分比
                  // =========================
                  Text(
                    '$percent%',
                    style: AppTextStyles.titleMediumBold.copyWith(
                      color: _topColor,
                      fontSize: 28,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // =========================
                  // 長條進度條
                  // =========================
                  Container(
                    width: double.infinity,
                    height: 22,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _skipBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
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

                  // =========================
                  // 狀態文字
                  // =========================
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

  const _StoryGameContent({
    required this.story,
    required this.onNextStory,
    required this.isSpeaking,
    required this.isLast,
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
            bottom: storyBottom + navigationReserve - 18,
            child: IgnorePointer(
              child: Image.asset(
                'img/npc_.png',
                width: 200,
                height: 285,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(width: 200, height: 285);
                },
              ),
            ),
          ),
          Positioned(
            left: 9,
            right: 9,
            bottom: storyBottom,
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
      onEnter: (_) {
        onHoverEnter();
      },
      onExit: (_) {
        onHoverExit();
      },
      child: GestureDetector(
        onTap: onTap,
        onTapDown: (_) {
          onPress();
        },
        onTapUp: (_) {
          onRelease();
        },
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
                      color: Colors.black.withOpacity(0.18),
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

/// 劇情的一句話：誰說的（名牌上的名字）、說了什麼。
/// voice 是唸這句的聲線（NPC 的 npc_voice，沒有時後端用預設聲線）；
/// npcName 是唸這句的 NPC（後端用它決定聲音，沒有時用薯光）；
/// backgroundUrl 是這句的背景圖（沒有就用劇情頁隨機挑的那張）；audioPath 是準備好的語音檔
class StoryLine {
  final String name;
  final String text;
  final String? voice;
  final String? npcName;
  final String? backgroundUrl;
  final String? audioPath;

  const StoryLine({
    required this.name,
    required this.text,
    this.voice,
    this.npcName,
    this.backgroundUrl,
    this.audioPath,
  });

  StoryLine copyWith({
    String? name,
    String? text,
    String? voice,
    String? npcName,
    String? backgroundUrl,
    String? audioPath,
  }) {
    return StoryLine(
      name: name ?? this.name,
      text: text ?? this.text,
      voice: voice ?? this.voice,
      npcName: npcName ?? this.npcName,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}

/// 一句話：到。！？為止，後面緊接的引號、括號算同一句
final RegExp _sentencePattern = RegExp(r'[^。！？!?]+(?:[。！？!?]+[」』”’）)]*)?');

/// 一行開頭寫明是誰說的，例如「薯光：」「薯光說：」
final RegExp _speakerPattern = RegExp(r'^\s*([^\s：:，,。！？!?「」]{1,8}?)說?[：:]\s*');

/// 把一段劇情拆成一句一句，劇情頁一次顯示、唸一句。換行也算一句結束；
/// 一行開頭寫明「某某：」或「某某說：」的，那一行算那個人說的，其他算 [speaker] 說的
List<StoryLine> splitStoryLines(
  String text, {
  required String speaker,
  String? voice,
  String? npcName,
  String? backgroundUrl,
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

      if (sentence.isNotEmpty) {
        lines.add(
          StoryLine(
            name: name,
            text: sentence,
            voice: voice,
            npcName: npcName,
            backgroundUrl: backgroundUrl,
          ),
        );
      }
    }
  }

  return lines;
}
