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

class StoryPage extends StatefulWidget {
  final Map<String, dynamic>? generatedScript;

  const StoryPage({super.key, this.generatedScript});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;

  static const double maxScale = 1.15;
  static const double topSpacePercent = 0.05;

  final AudioPlayer _npcAudioPlayer = AudioPlayer();

  bool _isSpeaking = false;
  bool _isPreparing = true;
  bool _isDisposed = false;

  String _loadingText = '正在準備劇情資訊…';

  double _voiceProgress = 0.0;

  int currentIndex = 1;

  int locationCurrent = 1;
  int locationTotal = 16;

  int postcardCurrent = 1;
  int postcardTotal = 10;

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

  String get _storyId {
    final String id =
        widget.generatedScript?['story_id']?.toString().trim() ?? '';

    return id.isNotEmpty
        ? id
        : _scriptData?['story_id']?.toString().trim() ?? '';
  }

  String get _npcName {
    final dynamic npc = _scriptData?['npc'];

    if (npc is Map) {
      final String name = npc['name']?.toString().trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'NPC';
  }

  Map<String, String> _parseDialogue(String dialogue) {
    final String value = dialogue.trim();

    if (value.isEmpty) {
      return {'speaker': _npcName, 'text': ''};
    }

    int separatorIndex = value.indexOf('：');

    if (separatorIndex < 0) {
      separatorIndex = value.indexOf(':');
    }

    if (separatorIndex < 0) {
      return {'speaker': _npcName, 'text': value};
    }

    final String speaker = value.substring(0, separatorIndex).trim();

    final String text = value.substring(separatorIndex + 1).trim();

    return {'speaker': speaker.isEmpty ? _npcName : speaker, 'text': text};
  }

  List<String> _splitSentences(String text) {
    final String value = text.trim();

    if (value.isEmpty) {
      return [];
    }

    final List<String> result = [];

    final StringBuffer current = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final String char = value[i];

      current.write(char);

      if (char == '。' ||
          char == '！' ||
          char == '？' ||
          char == '!' ||
          char == '?') {
        final String sentence = current.toString().trim();

        if (sentence.isNotEmpty) {
          result.add(sentence);
        }

        current.clear();
      }
    }

    final String remaining = current.toString().trim();

    if (remaining.isNotEmpty) {
      result.add(remaining);
    }

    return result;
  }

  void _addTextAsSentences({
    required List<StoryLine> target,
    required String speaker,
    required String text,
    required int nodeIndex,
  }) {
    final List<String> sentences = _splitSentences(text);

    for (final String sentence in sentences) {
      target.add(
        StoryLine(nodeIndex: nodeIndex, name: speaker, text: sentence),
      );
    }
  }

  void _collectDialogueValue({
    required List<StoryLine> target,
    required dynamic value,
    required int nodeIndex,
    String? fallbackSpeaker,
  }) {
    if (value == null) {
      return;
    }

    if (value is String) {
      final String text = value.trim();

      if (text.isEmpty) {
        return;
      }

      final Map<String, String> parsed = _parseDialogue(text);

      final bool hasSpeaker = text.contains('：') || text.contains(':');

      _addTextAsSentences(
        target: target,
        speaker: hasSpeaker
            ? parsed['speaker'] ?? _npcName
            : fallbackSpeaker ?? _npcName,
        text: hasSpeaker ? parsed['text'] ?? '' : text,
        nodeIndex: nodeIndex,
      );

      return;
    }

    if (value is List) {
      for (final dynamic item in value) {
        _collectDialogueValue(
          target: target,
          value: item,
          nodeIndex: nodeIndex,
          fallbackSpeaker: fallbackSpeaker,
        );
      }

      return;
    }

    if (value is Map) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(value);

      final dynamic speakerValue =
          map['speaker'] ??
          map['name'] ??
          map['character'] ??
          fallbackSpeaker ??
          _npcName;

      final String speaker = speakerValue.toString().trim();

      final dynamic textValue =
          map['text'] ?? map['content'] ?? map['dialogue'] ?? map['line'];

      if (textValue != null) {
        _addTextAsSentences(
          target: target,
          speaker: speaker.isEmpty ? _npcName : speaker,
          text: textValue.toString(),
          nodeIndex: nodeIndex,
        );

        return;
      }

      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (entry.key == 'speaker' ||
            entry.key == 'name' ||
            entry.key == 'character' ||
            entry.key == 'text' ||
            entry.key == 'content' ||
            entry.key == 'dialogue' ||
            entry.key == 'line') {
          continue;
        }

        _collectDialogueValue(
          target: target,
          value: entry.value,
          nodeIndex: nodeIndex,
          fallbackSpeaker: entry.key,
        );
      }
    }
  }

  List<StoryLine> _buildStoryLines() {
    final List<StoryLine> lines = [];

    final String preface = _scriptData?['preface']?.toString().trim() ?? '';

    if (preface.isNotEmpty) {
      lines.add(StoryLine(nodeIndex: -1, name: '旁白', text: preface));
    }

    final List<Map<String, dynamic>> nodes = _nodes;

    for (int nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
      final Map<String, dynamic> node = nodes[nodeIndex];

      final dynamic dialogues = node['dialogues'] ?? node['opening'];
      if (dialogues is Map) {
        final Map<String, dynamic> dialogueMap = Map<String, dynamic>.from(
          dialogues,
        );

        for (final MapEntry<String, dynamic> entry in dialogueMap.entries) {
          _collectDialogueValue(
            target: lines,
            value: entry.value,
            nodeIndex: nodeIndex,
            fallbackSpeaker: entry.key == 'opening' ? _npcName : null,
          );
        }
      } else {
        _collectDialogueValue(
          target: lines,
          value: dialogues,
          nodeIndex: nodeIndex,
          fallbackSpeaker: _npcName,
        );
      }
    }

    return lines;
  }

  Future<void> _prepareAllVoices() async {
    try {
      final List<StoryLine> lines = _buildStoryLines();

      if (lines.isEmpty) {
        if (mounted) {
          setState(() {
            _storyLines = [
              const StoryLine(nodeIndex: -1, name: '旁白', text: '目前尚未取得劇本內容。'),
            ];

            _voiceProgress = 1.0;
            _isPreparing = false;
          });
        }

        return;
      }

      final List<StoryLine> preparedLines = [];

      if (mounted) {
        setState(() {
          _voiceProgress = 0.0;
          _loadingText = '正在建立劇情語音…';
        });
      }

      for (int i = 0; i < lines.length; i++) {
        if (_isDisposed) {
          return;
        }

        final StoryLine line = lines[i];

        String localPath;

        if (line.nodeIndex == -1 && _storyId.isNotEmpty) {
          try {
            localPath = await StoryApi.preparePrologueVoice(storyId: _storyId);
          } catch (_) {
            localPath = await StoryApi.prepareNpcVoice(text: line.text);
          }
        } else {
          localPath = await StoryApi.prepareNpcVoice(text: line.text);
        }

        preparedLines.add(line.copyWith(audioPath: localPath));
        if (mounted) {
          setState(() {
            _voiceProgress = (i + 1) / lines.length;
          });
        }
      }

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
    } catch (e) {
      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _isPreparing = false;
        _loadingText = '劇情語音準備失敗';
      });
    }
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
    if (!mounted) {
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

    _prepareAllVoices();
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
        : const StoryLine(nodeIndex: -1, name: '旁白', text: '目前尚未取得劇本內容。');

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
                  child: _BackgroundImage(imageUrl: backgroundUrl),
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
                            locationCurrent: locationCurrent,
                            locationTotal: locationTotal,
                            postcardCurrent: postcardCurrent,
                            postcardTotal: postcardTotal,
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
        bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
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

class StoryLine {
  final int nodeIndex;
  final String name;
  final String text;
  final String? audioPath;

  const StoryLine({
    required this.nodeIndex,
    required this.name,
    required this.text,
    this.audioPath,
  });

  StoryLine copyWith({
    int? nodeIndex,
    String? name,
    String? text,
    String? audioPath,
  }) {
    return StoryLine(
      nodeIndex: nodeIndex ?? this.nodeIndex,
      name: name ?? this.name,
      text: text ?? this.text,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}
