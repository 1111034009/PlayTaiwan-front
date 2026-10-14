import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../api/story_api.dart';
import '../api/pair_api.dart';

import '../block/navigationbar.dart';
import 'choose_script_page.dart';
import 'story_play_page.dart';
import 'pair_lobby_page.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;

const Color _photoColor = Color(0xFFCBB57C);
const Color _photoBorder = AppColors.postcardLine;

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

const Color _sectionRed = AppColors.primaryAccent;

class ScriptDetailPage extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? generatedScript;
  final Map<String, dynamic>? allGeneratedScripts;
  final String cityName;
  final String townName;
  final List<String> transportation;
  final String storyId;
  final int partySize;
  const ScriptDetailPage({
    super.key,
    this.title = '',
    this.generatedScript,
    this.allGeneratedScripts,
    this.cityName = '',
    this.townName = '',
    this.transportation = const [],
    this.storyId = '',
    this.partySize = 1,
  });

  @override
  State<ScriptDetailPage> createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends State<ScriptDetailPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  static const double contentScale = 1.06;

  int currentIndex = 1;

  bool buttonHovering = false;
  bool buttonPressing = false;
  bool isConfirming = false;

  Map<String, dynamic>? _script;
  late String _title;
  bool _isLoadingDetail = false;
  String? _loadError;

  bool _isFavorite = false;
  bool _isTogglingFavorite = false;

  static const List<String> photoAssets = [
    'img/home_trip.png',
    'img/home_gogo.png',
    'img/home_gogo.png',
  ];

  // ============================================================
  // API 劇本資料
  // ============================================================

  Map<String, dynamic>? get _scriptData {
    final dynamic data = _script?['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return null;
  }

  String get _storyId {
    final String id = _script?['story_id']?.toString().trim() ?? '';

    return id.isNotEmpty ? id : widget.storyId.trim();
  }

  String get _preface {
    final String preface = _scriptData?['preface']?.toString().trim() ?? '';

    final String synopsis = _scriptData?['synopsis']?.toString().trim() ?? '';

    return '$preface$synopsis';
  }

  List<Map<String, dynamic>> get _nodes {
    final dynamic nodes = _scriptData?['nodes'];

    if (nodes is! List) {
      return [];
    }

    int orderOf(Map<String, dynamic> node) {
      return int.tryParse(
            (node['node_order'] ?? node['order'])?.toString() ?? '',
          ) ??
          0;
    }

    return nodes
        .whereType<Map>()
        .map((node) => Map<String, dynamic>.from(node))
        .toList()
      ..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
  }

  // 輪播圖片：使用 API 回傳的 image_url；第一張只顯示圖片，其餘顯示圖片+文字
  List<Widget> get _photoItems {
    final nodes = _nodes;

    if (nodes.isEmpty) {
      return photoAssets
          .map((asset) => _PolaroidPhoto(fallbackAsset: asset))
          .toList();
    }

    return List.generate(nodes.length, (index) {
      final Map<String, dynamic> node = nodes[index];
      final String url = node['image_url']?.toString().trim() ?? '';
      final String name = node['place_name']?.toString().trim() ?? '';

      return _PolaroidPhoto(
        imageUrl: url,
        fallbackAsset: photoAssets[index % photoAssets.length],
        caption: index == 0 ? null : name,
      );
    });
  }

  String _nodeDisplayName(Map<String, dynamic> node, int index) {
    if (index == 0) {
      return node['location_codename']?.toString() ?? '';
    }

    return node['place_name']?.toString() ?? '';
  }

  // ============================================================
  // 初始化
  // ============================================================

  @override
  void initState() {
    super.initState();

    _script = widget.generatedScript;
    _title = widget.title;
    _isFavorite = _scriptData?['is_favorite'] == true;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    if (_storyId.isNotEmpty && (_scriptData == null || _nodes.isEmpty)) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    final String id = _storyId;

    setState(() {
      _isLoadingDetail = true;
      _loadError = null;
    });

    try {
      final Map<String, dynamic> result = await StoryApi.getStoryDetail(
        storyId: id,
      );

      if (!mounted) return;

      final String title = result['title']?.toString().trim() ?? '';

      setState(() {
        _script = {'story_id': id, 'data': result};
        _isFavorite = result['is_favorite'] == true;

        if (title.isNotEmpty) {
          _title = title;
        }

        _isLoadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingDetail = false;
      });
    }
  }
  // ============================================================
  // 導航
  // ============================================================

  void backToChooseScript() {
    if (widget.allGeneratedScripts == null) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChooseScriptPage(
          generatedScript: widget.allGeneratedScripts,
          cityName: widget.cityName,
          townName: widget.townName,
          transportation: widget.transportation,
          partySize: widget.partySize,
        ),
      ),
    );
  }

  Future<void> toggleFavorite() async {
    if (_isTogglingFavorite || _storyId.isEmpty) {
      if (_storyId.isEmpty) _showMessage('找不到劇本 ID');
      return;
    }

    final bool nextValue = !_isFavorite;

    setState(() {
      _isTogglingFavorite = true;
    });

    try {
      await StoryApi.setFavorite(storyId: _storyId, isFavorite: nextValue);

      if (!mounted) return;

      setState(() {
        _isFavorite = nextValue;
      });

      _showMessage(nextValue ? '已加入喜愛' : '已取消喜愛');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingFavorite = false;
        });
      }
    }
  }

  Future<void> confirmScript() async {
    if (isConfirming) return;

    if (_storyId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到劇本 ID')));
      return;
    }

    setState(() {
      isConfirming = true;
    });

    try {
      final Map<String, dynamic> confirmResponse = await StoryApi.confirmStory(
        storyId: _storyId,
      );

      final result = confirmResponse['Result'];

      if (result is! Map) {
        throw Exception('取得完整劇本內容失敗');
      }

      final Map<String, dynamic> storyForStoryPage = {
        'story_id': _storyId,
        'data': Map<String, dynamic>.from(result),
      };

      final Map<String, dynamic>? pair = widget.partySize > 1
          ? await PairApi.createCode(storyId: _storyId)
          : null;

      if (!mounted) return;

      final Widget next = pair == null
          ? StoryPage(generatedScript: storyForStoryPage)
          : PairLobbyPage(pair: pair, story: storyForStoryPage);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isConfirming = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: _sectionRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,

      body: Transform.translate(
        offset: const Offset(0, -32),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: Transform.scale(
                scale: contentScale,
                alignment: Alignment.center,
                child: SizedBox(
                  width: designWidth,
                  height: designHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ====================================================
                      // 背景
                      // ====================================================

                      Positioned.fill(child: Container(color: _pageColor)),

                      Positioned(
                        left: 12,
                        top: 37,
                        width: 336,
                        height: 590,
                        child: Image.asset(
                          'img/long_papper.png',
                          fit: BoxFit.fill,
                        ),
                      ),

                      // ====================================================
                      // 劇本標題
                      // ====================================================
                      Positioned(
                        left: 34,
                        right: 100,
                        top: 63,
                        child: Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: _darkText,
                          ),
                        ),
                      ),

                      Positioned(
                        right: 62,
                        top: 57,
                        child: _FavoriteButton(
                          isFavorite: _isFavorite,
                          loading: _isTogglingFavorite,
                          onTap: toggleFavorite,
                        ),
                      ),

                      // ====================================================
                      // 關閉按鈕
                      // ====================================================
                      Positioned(
                        right: 28,
                        top: 57,
                        child: _CloseButton(onTap: backToChooseScript),
                      ),

                      // ====================================================
                      // 圖片輪播
                      // ====================================================
                      Positioned(
                        left: 30,
                        top: 107,
                        width: 300,
                        height: 154,
                        child: FlutterCarousel(
                          options: FlutterCarouselOptions(
                            height: 154,
                            viewportFraction: 0.68,
                            initialPage: 0,
                            enableInfiniteScroll: true,
                            autoPlay: false,
                            enlargeCenterPage: true,
                            showIndicator: false,
                            pageSnapping: true,
                            scrollDirection: Axis.horizontal,
                            enlargeStrategy: CenterPageEnlargeStrategy.scale,
                          ),
                          items: _photoItems,
                        ),
                      ),

                      // ====================================================
                      // 輪播提示
                      // ====================================================
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 265,
                        child: Text(
                          '←  左右滑動探索  → \n(迷霧圖片尚未解鎖)',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.microLabel.copyWith(
                            color: _darkBrown,
                          ),
                        ),
                      ),

                      // ====================================================
                      // 內容區
                      // ====================================================
                      Positioned(
                        left: 34,
                        right: 34,
                        top: 305,
                        bottom: 112,
                        child: _isLoadingDetail
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: _sectionRed,
                                ),
                              )
                            : ScrollConfiguration(
                                behavior: const _NoScrollbarScrollBehavior(),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    right: 8,
                                    bottom: 14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '前傳',
                                        style: AppTextStyles.sectionTitle
                                            .copyWith(color: _sectionRed),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        _preface.isNotEmpty
                                            ? _preface
                                            : (_loadError ?? '目前尚未取得劇本前傳。'),
                                        style: AppTextStyles.captionWide
                                            .copyWith(
                                              color: _darkText,
                                              height: 1.42,
                                            ),
                                      ),

                                      const SizedBox(height: 14),

                                      Row(
                                        children: [
                                          Text(
                                            '探索總覽',
                                            style: AppTextStyles.sectionTitle
                                                .copyWith(color: _sectionRed),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '往上滑動看更多',
                                            textAlign: TextAlign.center,
                                            style: AppTextStyles.microBold
                                                .copyWith(
                                                  color: _darkBrown.withValues(
                                                    alpha: 0.55,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 6),
                                      if (_nodes.isEmpty)
                                        Text(
                                          '目前尚未取得探索站點。',
                                          style: AppTextStyles.captionWide
                                              .copyWith(color: _darkText),
                                        )
                                      else
                                        ...List.generate(_nodes.length, (
                                          index,
                                        ) {
                                          final Map<String, dynamic> node =
                                              _nodes[index];

                                          return _ChapterItem(
                                            number: '第${index + 1}站',
                                            title: _nodeDisplayName(
                                              node,
                                              index,
                                            ),
                                          );
                                        }),

                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                      ),

                      // ====================================================
                      // 確認此卷
                      // ====================================================
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 55,
                        child: Center(
                          child: _ConfirmButton(
                            text: '遊玩此卷',
                            hovering: buttonHovering,
                            pressing: buttonPressing,
                            loading: isConfirming,
                            onHoverEnter: () {
                              setState(() {
                                buttonHovering = true;
                              });
                            },

                            onHoverExit: () {
                              setState(() {
                                buttonHovering = false;
                              });
                            },

                            onPress: () {
                              setState(() {
                                buttonPressing = true;
                              });
                            },

                            onRelease: () {
                              setState(() {
                                buttonPressing = false;
                              });
                            },

                            onTap: confirmScript,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ============================================================================
// Polaroid Photo
// ============================================================================

class _PolaroidPhoto extends StatelessWidget {
  final String imageUrl;
  final String fallbackAsset;
  final String? caption;

  const _PolaroidPhoto({
    this.imageUrl = '',
    required this.fallbackAsset,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Image.asset(
      fallbackAsset,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
    final String? text = caption;
    final bool showCaption = text != null && text.isNotEmpty;

    return Container(
      width: 176,
      height: 145,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 10),
      decoration: BoxDecoration(
        color: _photoColor,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _photoBorder, width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: imageUrl.isEmpty
                  ? fallback
                  : Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : fallback,
                      errorBuilder: (context, error, stack) => fallback,
                    ),
            ),
          ),

          if (showCaption) ...[
            const SizedBox(height: 5),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.microTightBold.copyWith(color: _darkBrown),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Chapter Item
// ============================================================================

class _ChapterItem extends StatelessWidget {
  final String number;
  final String title;

  const _ChapterItem({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: AppTextStyles.captionBold.copyWith(color: _darkText),
          ),

          Text(
            '$number：',
            style: AppTextStyles.captionBold.copyWith(color: _darkText),
          ),

          Expanded(
            child: Text(
              title,
              style: AppTextStyles.captionBold.copyWith(color: _darkText),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Favorite Button
// ============================================================================

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final bool loading;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.isFavorite,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _sectionRed,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey<bool>(isFavorite),
                    size: 24,
                    color: _sectionRed,
                  ),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// Close Button
// ============================================================================

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.90
        : hovering
        ? 1.10
        : 1.0;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        onTap: widget.onTap,

        onTapDown: (_) {
          setState(() {
            pressing = true;
          });
        },

        onTapUp: (_) {
          setState(() {
            pressing = false;
          });
        },

        onTapCancel: () {
          setState(() {
            pressing = false;
          });
        },

        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Image.asset(
                'img/NO.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Confirm Button
// ============================================================================

class _ConfirmButton extends StatelessWidget {
  final String text;

  final bool hovering;
  final bool pressing;
  final bool loading;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  final VoidCallback onPress;
  final VoidCallback onRelease;

  final VoidCallback onTap;

  const _ConfirmButton({
    required this.text,
    required this.hovering,
    required this.pressing,
    required this.loading,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onPress,
    required this.onRelease,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.08
        : 1.0;

    return MouseRegion(
      onEnter: (_) {
        onHoverEnter();
      },

      onExit: (_) {
        onHoverExit();
      },

      child: GestureDetector(
        onTap: loading ? null : onTap,
        onTapDown: loading
            ? null
            : (_) {
                onPress();
              },
        onTapUp: loading
            ? null
            : (_) {
                onRelease();
              },

        onTapCancel: loading
            ? null
            : () {
                onRelease();
              },

        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutBack,
          child: Container(
            width: 224,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),

              border: Border.all(color: _buttonBorder, width: 2),

              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_buttonCenter, _buttonCenter, _buttonOuter],
                stops: [0.0, 0.45, 1.0],
              ),

              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),

            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyEmphasisBold.copyWith(
                      color: AppColors.paper,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// No Scrollbar
// ============================================================================

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
