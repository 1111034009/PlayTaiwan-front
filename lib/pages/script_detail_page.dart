import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

import '../block/navigationbar.dart';
import 'choose_script_page.dart';
import 'story_play_page.dart';

// ============================================================
// 頁面配色
// ============================================================

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;

const Color _photoColor = Color(0xFFCBB57C);
const Color _photoBorder = Color(0xFF8D7B6E);

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

const Color _sectionRed = AppColors.primaryAccent;

// ============================================================
// 劇本詳細頁
// ============================================================

class ScriptDetailPage extends StatefulWidget {
  final String title;

  const ScriptDetailPage({super.key, this.title = '府城儒生失落卷'});

  @override
  State<ScriptDetailPage> createState() => _ScriptDetailPageState();
}

class _ScriptDetailPageState extends State<ScriptDetailPage> {
  // 固定設計畫布尺寸
  static const double designWidth = 360;
  static const double designHeight = 640;

  // 整體內容稍微放大
  static const double contentScale = 1.06;

  int currentIndex = 1;

  bool buttonHovering = false;
  bool buttonPressing = false;

  // 圖片輪播素材
  static const List<String> photoAssets = [
    'img/home_trip.png',
    'img/home_gogo.png',
    'img/home_gogo.png',
  ];

  @override
  void initState() {
    super.initState();

    // 設定系統狀態列與底部系統導覽列顏色
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

  // 統一使用 Kaisei Haruno Umi 字體
  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _darkBrown,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // 返回劇本選擇頁
  void backToChooseScript() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChooseScriptPage()),
    );
  }

  void confirmScript() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,

      // ========================================================
      // 主內容區
      // ========================================================
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: designWidth,
            height: designHeight,
            child: Transform.scale(
              // 整個劇本區塊以中心點放大，保持水平與垂直置中
              scale: contentScale,
              alignment: Alignment.center,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ==================================================
                    // 頁面背景
                    // ==================================================
                    Positioned.fill(child: Container(color: _pageColor)),

                    // ==================================================
                    // 長紙張背景
                    // ==================================================
                    Positioned(
                      left: 12,
                      top: 37,
                      width: 336,
                      height: 598,
                      child: Image.asset(
                        'img/long_papper.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // ==================================================
                    // 劇本標題
                    // ==================================================
                    Positioned(
                      left: 34,
                      right: 82,
                      top: 63,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kaisei(
                          size: 22,
                          weight: FontWeight.w700,
                          color: _darkText,
                        ),
                      ),
                    ),

                    // ==================================================
                    // 右上角關閉按鈕
                    // ==================================================
                    Positioned(
                      right: 28,
                      top: 57,
                      child: _CloseButton(onTap: backToChooseScript),
                    ),

                    // ==================================================
                    // 圖片輪播
                    // ==================================================
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
                          return _PolaroidPhoto(
                            assetPath: asset,
                            kaisei: kaisei,
                          );
                        }).toList(),
                      ),
                    ),

                    // ==================================================
                    // 劇本內容區
                    // ==================================================
                    Positioned(
                      left: 34,
                      right: 34,
                      top: 260,
                      bottom: 112,
                      child: ScrollConfiguration(
                        behavior: const _NoScrollbarScrollBehavior(),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(right: 8, bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==================================================
                              // 前傳
                              // ==================================================
                              Text(
                                '前傳',
                                style: kaisei(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: _sectionRed,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                '清朝年間，一位準備赴考的考生，在考試前夕離奇失去了所有記憶。醒來後，他只記得自己必須尋回某樣重要的東西，卻忘了那究竟是什麼。循著府城百年街巷的足跡，尋回逝去的一段段記憶，逐漸拼回真相。',
                                style: kaisei(
                                  size: 13.5,
                                  weight: FontWeight.w700,
                                  color: _darkText,
                                ).copyWith(height: 1.42),
                              ),

                              const SizedBox(height: 14),

                              // ==================================================
                              // 探索總覽
                              // ==================================================
                              Text(
                                '探索總覽',
                                style: kaisei(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: _sectionRed,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // ==================================================
                              // 第一站
                              // ==================================================
                              _ChapterItem(
                                number: '第一站',
                                title: '臺南孔廟',
                                kaisei: kaisei,
                              ),

                              // ==================================================
                              // 第二站
                              // ==================================================
                              _ChapterItem(
                                number: '第二站',
                                title: '尋找文字的故鄉',
                                kaisei: kaisei,
                              ),

                              // ==================================================
                              // 第三站
                              // ==================================================
                              _ChapterItem(
                                number: '第三站',
                                title: '追尋百年前的繁華',
                                kaisei: kaisei,
                              ),

                              // ==================================================
                              // 第四站
                              // ==================================================
                              _ChapterItem(
                                number: '第四站',
                                title: '破解古城石碑',
                                kaisei: kaisei,
                              ),

                              // ==================================================
                              // 第五站
                              // ==================================================
                              _ChapterItem(
                                number: '第五站',
                                title: '尋找失落記憶',
                                kaisei: kaisei,
                              ),

                              // ==================================================
                              // 第六站
                              // ==================================================
                              _ChapterItem(
                                number: '第六站',
                                title: '解開最後謎題',
                                kaisei: kaisei,
                              ),

                              // ==================================================
                              // 第七站
                              // ==================================================
                              _ChapterItem(
                                number: '第七站',
                                title: '回到故事最初的地方',
                                kaisei: kaisei,
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ==================================================
                    // 底部確認按鈕
                    // ==================================================
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 57,
                      child: Center(
                        child: _ConfirmButton(
                          text: '確認此卷',
                          hovering: buttonHovering,
                          pressing: buttonPressing,

                          // 滑鼠移入
                          onHoverEnter: () {
                            setState(() {
                              buttonHovering = true;
                            });
                          },

                          // 滑鼠移出
                          onHoverExit: () {
                            setState(() {
                              buttonHovering = false;
                            });
                          },

                          // 按下按鈕
                          onPress: () {
                            setState(() {
                              buttonPressing = true;
                            });
                          },

                          // 放開按鈕
                          onRelease: () {
                            setState(() {
                              buttonPressing = false;
                            });
                          },

                          // 點擊確認
                          onTap: confirmScript,
                          kaisei: kaisei,
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

      // ============================================================
      // 底部導覽列
      // ============================================================
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ============================================================
// 圖片卡片
// ============================================================

class _PolaroidPhoto extends StatelessWidget {
  final String assetPath;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _PolaroidPhoto({required this.assetPath, required this.kaisei});

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
          // 圖片
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

          // 圖片名稱
          Text(
            '臺南景點',
            textAlign: TextAlign.center,
            style: kaisei(
              size: 10.5,
              weight: FontWeight.w700,
              color: _darkBrown,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 探索章節項目
// ============================================================

class _ChapterItem extends StatelessWidget {
  final String number;
  final String title;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _ChapterItem({
    required this.number,
    required this.title,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 項目符號
          Text(
            '• ',
            style: kaisei(size: 13, weight: FontWeight.w700, color: _darkText),
          ),

          // 站點編號
          Text(
            '$number：',
            style: kaisei(size: 13, weight: FontWeight.w700, color: _darkText),
          ),

          // 站點名稱
          Expanded(
            child: Text(
              title,
              style: kaisei(
                size: 13,
                weight: FontWeight.w700,
                color: _darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 右上角關閉按鈕
// ============================================================

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
    // 控制滑鼠移入與按下時的縮放效果
    final double scale = pressing
        ? 0.90
        : hovering
        ? 1.10
        : 1.0;

    return MouseRegion(

      // 滑鼠移入
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      // 滑鼠移出
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        // 點擊關閉
        onTap: widget.onTap,

        // 按下
        onTapDown: (_) {
          setState(() {
            pressing = true;
          });
        },

        // 放開
        onTapUp: (_) {
          setState(() {
            pressing = false;
          });
        },

        // 取消按壓
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
            // 增加實際點擊範圍
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

// ============================================================
// 確認按鈕
// ============================================================

class _ConfirmButton extends StatelessWidget {
  final String text;

  final bool hovering;
  final bool pressing;

  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;

  final VoidCallback onPress;
  final VoidCallback onRelease;

  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _ConfirmButton({
    required this.text,
    required this.hovering,
    required this.pressing,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onPress,
    required this.onRelease,
    required this.onTap,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    // 控制滑鼠移入與按下時的縮放效果
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.08
        : 1.0;

    return MouseRegion(

      // 滑鼠移入
      onEnter: (_) {
        onHoverEnter();
      },

      // 滑鼠移出
      onExit: (_) {
        onHoverExit();
      },

      child: GestureDetector(
        // 點擊確認
        onTap: onTap,

        // 按下
        onTapDown: (_) {
          onPress();
        },

        // 放開
        onTapUp: (_) {
          onRelease();
        },

        // 取消按壓
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
              style: kaisei(
                size: 15,
                weight: FontWeight.w700,
                color: const Color(0xFFEBE1C7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 關閉 ScrollView 的預設 Scrollbar 與 Overscroll 效果
// ============================================================

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
