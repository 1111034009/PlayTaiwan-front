import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import '../block/navigationbar.dart';
import 'choose_script_page.dart';
import 'story_play_page.dart';

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

  const ScriptDetailPage({
    super.key,
    this.title = '府城儒生失落卷',
    this.generatedScript,
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

  static const List<String> photoAssets = [
    'img/home_trip.png',
    'img/home_gogo.png',
    'img/home_gogo.png',
  ];

  // ============================================================
  // API 劇本資料
  // ============================================================

  Map<String, dynamic>? get _scriptData {
    final dynamic data = widget.generatedScript?['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    return null;
  }

  String get _preface {
    return _scriptData?['preface']?.toString() ?? '';
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
        final int orderA = int.tryParse(a['node_order']?.toString() ?? '') ?? 0;

        final int orderB = int.tryParse(b['node_order']?.toString() ?? '') ?? 0;

        return orderA.compareTo(orderB);
      });
  }

  String _nodeDisplayName(Map<String, dynamic> node, int index) {
    if (index == 0) {
      return node['place_name']?.toString() ?? '';
    }

    return node['location_codename']?.toString() ?? '';
  }

  // ============================================================
  // 初始化
  // ============================================================

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ============================================================
  // 導航
  // ============================================================

  void backToChooseScript() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChooseScriptPage(generatedScript: widget.generatedScript),
      ),
    );
  }

  void confirmScript() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StoryPage(generatedScript: widget.generatedScript),
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
                        right: 82,
                        top: 63,
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: _darkText,
                          ),
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
                          items: photoAssets.map((asset) {
                            return _PolaroidPhoto(assetPath: asset);
                          }).toList(),
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
                          '←  左右滑動探索  →',
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
                        top: 285,
                        bottom: 112,
                        child: ScrollConfiguration(
                          behavior: const _NoScrollbarScrollBehavior(),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              right: 8,
                              bottom: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ==================================================
                                // 前傳
                                // ==================================================

                                Text(
                                  '前傳',
                                  style: AppTextStyles.sectionTitle.copyWith(
                                    color: _sectionRed,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  _preface.isNotEmpty
                                      ? _preface
                                      : '目前尚未取得劇本前傳。',
                                  style: AppTextStyles.captionWide.copyWith(
                                    color: _darkText,
                                    height: 1.42,
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // ==================================================
                                // 探索總覽標題
                                // ==================================================
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
                                      style: AppTextStyles.microBold.copyWith(
                                        color: _darkBrown.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // ==================================================
                                // 動態探索站
                                //
                                // 第一站：
                                //     place_name
                                //
                                // 第二站開始：
                                //     location_codename
                                //
                                // 有幾個 nodes 就顯示幾站
                                // ==================================================
                                if (_nodes.isEmpty)
                                  Text(
                                    '目前尚未取得探索站點。',
                                    style: AppTextStyles.captionWide.copyWith(
                                      color: _darkText,
                                    ),
                                  )
                                else
                                  ...List.generate(_nodes.length, (index) {
                                    final Map<String, dynamic> node =
                                        _nodes[index];

                                    return _ChapterItem(
                                      number: '第${index + 1}站',
                                      title: _nodeDisplayName(node, index),
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
                            text: '確認此卷',
                            hovering: buttonHovering,
                            pressing: buttonPressing,

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
  final String assetPath;

  const _PolaroidPhoto({required this.assetPath});

  @override
  Widget build(BuildContext context) {
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
              child: Image.asset(
                assetPath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '臺南景點',
            textAlign: TextAlign.center,
            style: AppTextStyles.microTightBold.copyWith(color: _darkBrown),
          ),
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

  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  final VoidCallback onPress;
  final VoidCallback onRelease;

  final VoidCallback onTap;

  const _ConfirmButton({
    required this.text,
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
        onTap: onTap,

        onTapDown: (_) {
          onPress();
        },

        onTapUp: (_) {
          onRelease();
        },

        onTapCancel: () {
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

            child: Text(
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
