import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

import '../block/navigationbar.dart';
import 'choose_script_page.dart';
import 'story_play_page.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;

const Color _photoColor = Color(0xFFCBB57C);
const Color _photoBorder = Color(0xFF8D7B6E);

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

const Color _sectionRed = AppColors.primaryAccent;

class ScriptDetailPage extends StatefulWidget {
  final String title;

  const ScriptDetailPage({super.key, this.title = '府城儒生失落卷'});

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

                      Positioned(
                        right: 28,
                        top: 57,
                        child: _CloseButton(onTap: backToChooseScript),
                      ),

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
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 265,
                        child: Text(
                          '←  左右滑動探索  →',
                          textAlign: TextAlign.center,
                          style: kaisei(
                            size: 11,
                            weight: FontWeight.w700,
                            color: _darkBrown,
                          ),
                        ),
                      ),
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

                                Row(
                                  children: [
                                    Text(
                                      '探索總覽',
                                      style: kaisei(
                                        size: 18,
                                        weight: FontWeight.w700,
                                        color: _sectionRed,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '往上滑動看更多',
                                      textAlign: TextAlign.center,
                                      style: kaisei(
                                        size: 10,
                                        weight: FontWeight.w700,
                                        color: _darkBrown.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),
                                _ChapterItem(
                                  number: '第一站',
                                  title: '臺南孔廟',
                                  kaisei: kaisei,
                                ),

                                _ChapterItem(
                                  number: '第二站',
                                  title: '尋找文字的故鄉',
                                  kaisei: kaisei,
                                ),

                                _ChapterItem(
                                  number: '第三站',
                                  title: '追尋百年前的繁華',
                                  kaisei: kaisei,
                                ),

                                _ChapterItem(
                                  number: '第四站',
                                  title: '破解古城石碑',
                                  kaisei: kaisei,
                                ),

                                _ChapterItem(
                                  number: '第五站',
                                  title: '尋找失落記憶',
                                  kaisei: kaisei,
                                ),

                                _ChapterItem(
                                  number: '第六站',
                                  title: '解開最後謎題',
                                  kaisei: kaisei,
                                ),

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
      ),

      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

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
          Text(
            '• ',
            style: kaisei(size: 13, weight: FontWeight.w700, color: _darkText),
          ),

          Text(
            '$number：',
            style: kaisei(size: 13, weight: FontWeight.w700, color: _darkText),
          ),

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
