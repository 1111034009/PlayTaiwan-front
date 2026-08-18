import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../block/navigationbar.dart';
import '../../block/story_location_popup.dart';
import '../../block/story_task_popup.dart';
import '../../block/topbar.dart';
import 'nearby_page.dart';
import 'story_play_page.dart';
import 'story_question_page.dart';

const Color _pageColor = Color(0xFFB9ACA2);
const Color _topColor = Color(0xFFEBE1C7);
const Color _darkText = Color(0xFF301717);

const Color _daySelectedBackground = Color(0xFF7F1A08);
const Color _daySelectedText = Color(0xFFEBE1C7);
const Color _dayUnselectedText = Color(0xFF301717);

class StoryMapPage extends StatefulWidget {
  const StoryMapPage({super.key});

  @override
  State<StoryMapPage> createState() => _StoryMapPageState();
}

class _StoryMapPageState extends State<StoryMapPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;
  static const double maxScale = 1.15;

  int currentIndex = 1;

  int locationCurrent = 1;
  int locationTotal = 16;

  int postcardCurrent = 1;
  int postcardTotal = 10;

  int selectedDay = 1;

  bool showLocationPopup = false;
  bool showTaskPopup = false;

  String selectedLocation = '臺南孔廟';

  String selectedDescription = '臺南孔廟座落於府城歷史文化核心，建於1665年，是臺灣歷史上第一所官學。';

  @override
  void initState() {
    super.initState();

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

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _darkText,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  double _getScale(double width, double height) {
    final double widthScale = width / designWidth;
    final double heightScale = height / designHeight;

    return math.min(math.min(widthScale, heightScale), maxScale);
  }

  void openConfuciusTemple() {
    setState(() {
      selectedLocation = '臺南孔廟';
      selectedDescription = '臺南孔廟座落於府城歷史文化核心，建於1665年，是臺灣歷史上第一所官學。';

      showLocationPopup = true;
      showTaskPopup = false;
    });
  }

  void closeLocationPopup() {
    setState(() {
      showLocationPopup = false;
    });
  }

  void openTaskPopup() {
    setState(() {
      showLocationPopup = false;
      showTaskPopup = true;
    });
  }

  void closeTaskPopup() {
    setState(() {
      showTaskPopup = false;
      showLocationPopup = true;
    });
  }

  void reviewStory() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StoryPage()),
    );
  }

  void startTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StoryQuestionPage()),
    );
  }

  void showNearby() {
    setState(() {
      showLocationPopup = false;
      showTaskPopup = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NearbyPage()),
    );
  }

  void showMission() {
    openTaskPopup();
  }

  void startNavigation() {
    showMessage('開始導航');
  }

  void goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: kaisei(
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF473737),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void onNavigationTap(int index) {
    setState(() {
      currentIndex = index;
    });

    if (index == 0) {
      goHome();
    }
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

            final double actualTopBarWidth = topBarDesignWidth * scale;

            final double actualTopBarHeight = topBarDesignHeight * scale;

            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: _MapBackground()),

                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: actualTopBarHeight,
                  child: const ColoredBox(color: _topColor),
                ),

                Positioned(
                  left: 0,
                  top: 0,
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
                  top: actualTopBarHeight + (6 * scale),
                  right: math.max(
                    5 * scale,
                    (screenWidth - actualTopBarWidth) / 2 + (1 * scale),
                  ),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: _DaySelector(
                      selectedDay: selectedDay,
                      onDayChanged: (day) {
                        setState(() {
                          selectedDay = day;
                        });
                      },
                      kaisei: kaisei,
                    ),
                  ),
                ),

                _MapViewport(
                  designWidth: designWidth,
                  designHeight: designHeight,
                  scale: scale,
                  child: _MapContent(onConfuciusTempleTap: openConfuciusTemple),
                ),

                if (showLocationPopup)
                  Positioned.fill(
                    child: _LocationPopupLayer(
                      selectedLocation: selectedLocation,
                      selectedDescription: selectedDescription,
                      onClose: closeLocationPopup,
                      onReviewStory: reviewStory,
                      onAround: showNearby,
                      onMission: showMission,
                      onNavigate: startNavigation,
                    ),
                  ),

                if (showTaskPopup)
                  Positioned.fill(
                    child: _TaskPopupLayer(
                      title: selectedLocation,
                      onClose: closeTaskPopup,
                      onReviewStory: reviewStory,
                      onBack: closeTaskPopup,
                      onStartTask: startTask,
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

class _MapBackground extends StatelessWidget {
  const _MapBackground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenHeight = constraints.maxHeight;

        return ColoredBox(
          color: _pageColor,
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Center(
              child: Image.asset(
                'img/example.png',
                height: screenHeight - 100,
                fit: BoxFit.fitHeight,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(
                    height: screenHeight - 100,
                    child: const ColoredBox(color: _pageColor),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapViewport extends StatelessWidget {
  final double designWidth;
  final double designHeight;
  final double scale;
  final Widget child;

  const _MapViewport({
    required this.designWidth,
    required this.designHeight,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: designWidth * scale,
          height: designHeight * scale,
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

class _MapContent extends StatelessWidget {
  final VoidCallback onConfuciusTempleTap;

  const _MapContent({required this.onConfuciusTempleTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      height: 640,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 16,
            top: 137,
            width: 150,
            height: 96,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onConfuciusTempleTap,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onDayChanged;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _DaySelector({
    required this.selectedDay,
    required this.onDayChanged,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DayButton(
                text: '第一日',
                selected: selectedDay == 1,
                onTap: () {
                  onDayChanged(1);
                },
                kaisei: kaisei,
              ),
              const SizedBox(width: 7),
              _DayButton(
                text: '第二日',
                selected: selectedDay == 2,
                onTap: () {
                  onDayChanged(2);
                },
                kaisei: kaisei,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayButton extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _DayButton({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_DayButton> createState() => _DayButtonState();
}

class _DayButtonState extends State<_DayButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.04
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: widget.selected
                  ? _daySelectedBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: widget.kaisei(
                size: 13,
                weight: FontWeight.w700,
                color: widget.selected ? _daySelectedText : _dayUnselectedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationPopupLayer extends StatefulWidget {
  final String selectedLocation;
  final String selectedDescription;

  final VoidCallback onClose;
  final VoidCallback onReviewStory;
  final VoidCallback onAround;
  final VoidCallback onMission;
  final VoidCallback onNavigate;

  const _LocationPopupLayer({
    required this.selectedLocation,
    required this.selectedDescription,
    required this.onClose,
    required this.onReviewStory,
    required this.onAround,
    required this.onMission,
    required this.onNavigate,
  });

  @override
  State<_LocationPopupLayer> createState() => _LocationPopupLayerState();
}

class _LocationPopupLayerState extends State<_LocationPopupLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Container(color: Colors.black.withOpacity(0.20)),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: StoryLocationPopup(
              title: widget.selectedLocation,
              description: widget.selectedDescription,
              onClose: widget.onClose,
              onReviewStory: widget.onReviewStory,
              onAround: widget.onAround,
              onMission: widget.onMission,
              onNavigate: widget.onNavigate,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskPopupLayer extends StatefulWidget {
  final String title;

  final VoidCallback onClose;
  final VoidCallback onReviewStory;
  final VoidCallback onBack;
  final VoidCallback onStartTask;

  const _TaskPopupLayer({
    required this.title,
    required this.onClose,
    required this.onReviewStory,
    required this.onBack,
    required this.onStartTask,
  });

  @override
  State<_TaskPopupLayer> createState() => _TaskPopupLayerState();
}

class _TaskPopupLayerState extends State<_TaskPopupLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: Container(color: Colors.black.withOpacity(0.20)),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: StoryTaskPopup(
              title: widget.title,
              onClose: widget.onClose,
              onReviewStory: widget.onReviewStory,
              onBack: widget.onBack,
              onStartTask: widget.onStartTask,
            ),
          ),
        ),
      ],
    );
  }
}
