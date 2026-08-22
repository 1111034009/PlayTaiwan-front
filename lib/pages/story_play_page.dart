import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../block/navigationbar.dart';
import '../block/topbar.dart';

const Color _pageColor = AppColors.background;
const Color _topColor = AppColors.paper;
const Color _darkText = AppColors.textPrimary;

const Color _skipStart = Color(0x66CBB57C);
const Color _skipEnd = Color(0x55AA9038);
const Color _skipBorder = Color(0xB8E3D1A4);

const Color _storyRed = Color(0xFF8D1F12);

class StoryPage extends StatefulWidget {
  final String title;

  const StoryPage({super.key, this.title = '府城儒生失落卷'});

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;

  static const double maxScale = 1.15;
  static const double topSpacePercent = 0.05;
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

  static const List<String> backgroundImages = [
    'https://images.pexels.com/photos/156934/pexels-photo-156934.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=1200&w=800',
    'https://images.pexels.com/photos/417173/pexels-photo-417173.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=1200&w=800',
    'https://images.pexels.com/photos/2212890/pexels-photo-2212890.jpeg?auto=compress&cs=tinysrgb&fit=crop&h=1200&w=800',
  ];

  static const List<StoryLine> storyLines = [
    StoryLine(name: '薯光', text: '歡迎來到這裡，你的記憶應該只停留在那邊對吧。'),
    StoryLine(name: '薯光', text: '從零開始，沿著留下的線索，我會陪伴你一步一步把它找回來。'),
    StoryLine(name: '薯光', text: '這趟旅程的第一站，就讓我們從歷史探索開始吧。'),
  ];

  @override
  void initState() {
    super.initState();

    backgroundUrl = backgroundImages[_random.nextInt(backgroundImages.length)];

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _topColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void nextStory() {
    if (storyIndex < storyLines.length - 1) {
      setState(() {
        storyIndex++;
      });
      return;
    }

    finishStory();
  }

  void skipStory() {
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
  Widget build(BuildContext context) {
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
          builder: (context, constraints) {
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
                    story: storyLines[storyIndex],
                    onNextStory: nextStory,
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

  const _StoryGameContent({required this.story, required this.onNextStory});

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
            child: _StoryDialog(story: story, onTap: onNextStory),
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
                  style: GoogleFonts.kaiseiHarunoUmi(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

  const _StoryDialog({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 128,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Image.asset(
                'img/story_box.png',
                width: double.infinity,
                height: 100,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8DFC9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF806C54)),
                    ),
                  );
                },
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
                  style: GoogleFonts.kaiseiHarunoUmi(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _topColor,
                    height: 1,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 15,
              right: 15,
              top: 46,
              child: Text(
                story.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.kaiseiHarunoUmi(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _darkText,
                  height: 1.45,
                ),
              ),
            ),

            Positioned(
              right: 13,
              bottom: 7,
              child: Text(
                '點擊繼續',
                style: GoogleFonts.kaiseiHarunoUmi(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF806C54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryLine {
  final String name;
  final String text;

  const StoryLine({required this.name, required this.text});
}
