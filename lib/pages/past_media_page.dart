import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import '../block/navigationbar.dart';
import 'past_page.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';

const Color _pageColor = AppColors.pastBackground;
const Color _darkBrown = AppColors.darkBrown;
const Color _videoPoster = AppColors.paper;

class PastMediaPage extends StatefulWidget {
  const PastMediaPage({super.key});

  @override
  State<PastMediaPage> createState() => _PastMediaPageState();
}

class _PastMediaPageState extends State<PastMediaPage> {
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static const double designWidth = 360;
  static const double designHeight = 640;
  static const double contentScale = 1;

  static const double postcardWidth = 180;
  static const double postcardHeight = 133;
  static const double postcardGap = 16;

  static const int specialPostcardIndex = 2;

  static const List<String> postcardAssets = [
    'img/example_postcard.png',
    'img/example_postcard.png',
    'img/example_postcard.png',
    'img/example_postcard.png',
    'img/example_postcard.png',
    'img/example_postcard.png',
    'img/example_postcard.png',
    'img/example_postcard.png',
  ];

  int currentIndex = 3;
  int? selectedPostcardIndex;
  bool showVideo = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void backToPast() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PastPage()),
    );
  }

  void openPostcard(int index) {
    setState(() {
      selectedPostcardIndex = index;
    });
  }

  void closePostcard() {
    setState(() {
      selectedPostcardIndex = null;
    });
  }

  void openVideo() {
    setState(() {
      showVideo = true;
    });
  }

  void closeVideo() {
    setState(() {
      showVideo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: screenSize.height * 0.01,
                    bottom: 190,
                  ),
                  child: Transform.scale(
                    scale: contentScale,
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: designWidth,
                        height: 700,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Positioned.fill(
                              child: ColoredBox(color: _pageColor),
                            ),
                            Positioned(
                              left: 22,
                              top: 49,
                              child: _BackButton(onTap: backToPast),
                            ),
                            Positioned(
                              left: 25,
                              top: 88,
                              child: _OutlinedTitle(text: '回憶vlog'),
                            ),
                            Positioned(
                              left: 15,
                              right: 15,
                              top: 130,
                              height: 350,
                              child: _VideoSection(onTap: openVideo),
                            ),
                            Positioned(
                              left: 25,
                              top: 500,
                              child: _OutlinedTitle(text: '明信片集結'),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 535,
                              height: 163,
                              child: _PostcardCarousel(
                                onPostcardTap: openPostcard,
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
          ),
          if (selectedPostcardIndex != null)
            Positioned.fill(
              child: _PostcardOverlay(
                assetPath: postcardAssets[selectedPostcardIndex!],
                isSpecial: selectedPostcardIndex == specialPostcardIndex,
                onClose: closePostcard,
              ),
            ),
          if (showVideo)
            Positioned.fill(child: _VideoOverlay(onClose: closeVideo)),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  double _designScale(Size size) {
    return AppResponsive.scale(
      availableWidth: size.width,
      availableHeight: size.height,
      designWidth: designWidth,
      designHeight: designHeight,
    );
  }

  double _postcardTop(Size size) {
    final double scale = _designScale(size);
    final double contentTop = size.height * 0.05;

    return contentTop + 510 * scale;
  }

  double _postcardCarouselHeight(Size size) {
    return 163 * _designScale(size);
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.95 : 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Text(
          '<< 返回',
          style: AppTextStyles.button.copyWith(color: const Color(0xFFE8DCC6)),
        ),
      ),
    );
  }
}

class _OutlinedTitle extends StatelessWidget {
  final String text;
  const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = AppTextStyles.heading
        .copyWith(color: Colors.white)
        .copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.black,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: outlineStyle),
        Text(text, style: AppTextStyles.heading.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _VideoSection extends StatelessWidget {
  final VoidCallback onTap;

  const _VideoSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 240,
          height: 426.67,
          decoration: BoxDecoration(
            color: _videoPoster,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _VideoOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const _VideoOverlay({required this.onClose});

  @override
  State<_VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<_VideoOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.82)),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final double value = Curves.easeOutBack.transform(
                      controller.value,
                    );

                    return Transform.scale(
                      scale: value,
                      child: GestureDetector(
                        onTap: () {},
                        child: const _VideoPlayerCard(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            right: 18,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerCard extends StatelessWidget {
  const _VideoPlayerCard();

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    final double width = math.min(screenSize.width * 0.92, 520.0);

    final double height = math.min(screenSize.height * 0.82, width * 16 / 9);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _videoPoster,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xAA000000), blurRadius: 30, spreadRadius: 5),
        ],
      ),
    );
  }
}

class _PostcardCarousel extends StatelessWidget {
  final ValueChanged<int> onPostcardTap;

  const _PostcardCarousel({required this.onPostcardTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FlutterCarousel(
        options: FlutterCarouselOptions(
          height: 163,
          viewportFraction: 0.55,
          initialPage: 1,
          enableInfiniteScroll: true,
          autoPlay: false,
          enlargeCenterPage: false,
          showIndicator: false,
          pageSnapping: true,
          scrollDirection: Axis.horizontal,
        ),
        items: List.generate(_PastMediaPageState.postcardAssets.length, (
          index,
        ) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _PastMediaPageState.postcardGap / 2,
              ),
              child: _PostcardCard(
                assetPath: _PastMediaPageState.postcardAssets[index],
                isSpecial: index == _PastMediaPageState.specialPostcardIndex,
                onTap: () => onPostcardTap(index),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PostcardCard extends StatefulWidget {
  final String assetPath;
  final bool isSpecial;
  final VoidCallback onTap;

  const _PostcardCard({
    required this.assetPath,
    required this.isSpecial,
    required this.onTap,
  });

  @override
  State<_PostcardCard> createState() => _PostcardCardState();
}

class _PostcardCardState extends State<_PostcardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  bool pressing = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    if (widget.isSpecial) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return _PostcardVisual(
              assetPath: widget.assetPath,
              isSpecial: widget.isSpecial,
              progress: controller.value,
            );
          },
        ),
      ),
    );
  }
}

class _PostcardVisual extends StatelessWidget {
  final String assetPath;
  final bool isSpecial;
  final double progress;

  const _PostcardVisual({
    required this.assetPath,
    required this.isSpecial,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _PastMediaPageState.postcardWidth,
      height: _PastMediaPageState.postcardHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: isSpecial
                ? Color.lerp(
                    const Color(0x44000000),
                    const Color(0xFF7568FF),
                    progress,
                  )!
                : const Color(0x44000000),
            blurRadius: isSpecial ? 14 : 6,
            spreadRadius: isSpecial ? 1 : 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            if (isSpecial)
              CustomPaint(painter: _NightCardPainter(progress: progress)),
          ],
        ),
      ),
    );
  }
}

class _StarData {
  final double x;
  final double y;
  final double radius;
  final double phase;

  const _StarData(this.x, this.y, this.radius, this.phase);
}

class _NightCardPainter extends CustomPainter {
  final double progress;

  const _NightCardPainter({required this.progress});

  static const List<_StarData> stars = [
    _StarData(0.10, 0.18, 1.2, 0.00),
    _StarData(0.25, 0.35, 0.9, 0.23),
    _StarData(0.76, 0.17, 1.4, 0.43),
    _StarData(0.88, 0.43, 1.0, 0.67),
    _StarData(0.18, 0.77, 1.1, 0.38),
    _StarData(0.78, 0.79, 1.5, 0.59),
    _StarData(0.52, 0.13, 0.8, 0.82),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final Paint tint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x332B2470),
          Color(0x11101845),
          Color(0x442E267A),
          Color(0x11101845),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, tint);

    final double shimmerX = -size.width + size.width * 2.4 * progress;

    final Paint shimmer = Paint()
      ..shader =
          const LinearGradient(
            colors: [
              Colors.transparent,
              Color(0x557D6CFF),
              Color(0xBBFFFFFF),
              Color(0x557D6CFF),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(shimmerX, 0, size.width * 0.65, size.height),
          );

    canvas.drawRect(rect, shimmer);

    final Paint starPaint = Paint();

    for (final star in stars) {
      final double wave = (progress + star.phase) % 1.0;

      final double glow = 1 - ((wave - 0.5).abs() * 2);

      final double opacity = (0.15 + glow * 0.85).clamp(0.1, 1.0);

      final Offset center = Offset(size.width * star.x, size.height * star.y);

      starPaint.color = Colors.white.withValues(alpha: opacity);

      canvas.drawCircle(center, star.radius, starPaint);

      if (star.radius > 1.2) {
        final Paint ray = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.35)
          ..strokeWidth = 0.7;

        canvas.drawLine(
          Offset(center.dx - star.radius * 2.8, center.dy),
          Offset(center.dx + star.radius * 2.8, center.dy),
          ray,
        );

        canvas.drawLine(
          Offset(center.dx, center.dy - star.radius * 2.8),
          Offset(center.dx, center.dy + star.radius * 2.8),
          ray,
        );
      }
    }

    final double meteor = (progress * 1.65) % 1.0;

    if (meteor > 0.70) {
      final double t = (meteor - 0.70) / 0.30;

      final Offset end = Offset(
        size.width * (0.20 + t * 0.65),
        size.height * (0.04 + t * 0.42),
      );

      final Offset start = Offset(
        end.dx - size.width * 0.16,
        end.dy - size.height * 0.12,
      );

      final double alpha = (1 - t).clamp(0.0, 1.0);

      final Paint meteorPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0x667D6CFF),
            Colors.white.withValues(alpha: alpha),
          ],
        ).createShader(Rect.fromPoints(start, end))
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, meteorPaint);

      canvas.drawCircle(
        end,
        2,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    final Paint mist = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0x005D5AEF), Color(0x225D5AEF), Color(0x005D5AEF)],
      ).createShader(rect);

    canvas.drawRect(rect, mist);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0x227D6CFF),
          Color(0xDDFFFFFF),
          Color(0x667D6CFF),
          Color(0x227D6CFF),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(3)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _NightCardPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PostcardOverlay extends StatefulWidget {
  final String assetPath;
  final bool isSpecial;
  final VoidCallback onClose;

  const _PostcardOverlay({
    required this.assetPath,
    required this.isSpecial,
    required this.onClose,
  });

  @override
  State<_PostcardOverlay> createState() => _PostcardOverlayState();
}

class _PostcardOverlayState extends State<_PostcardOverlay>
    with TickerProviderStateMixin {
  late final AnimationController openController;
  late final AnimationController effectController;

  @override
  void initState() {
    super.initState();

    openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    effectController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    if (widget.isSpecial) {
      effectController.repeat();
    }
  }

  @override
  void dispose() {
    openController.dispose();
    effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return GestureDetector(
                  onTap: widget.onClose,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 9 * value,
                      sigmaY: 9 * value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.74 * value),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: AnimatedBuilder(
                animation: openController,
                builder: (context, child) {
                  final double scale = Curves.easeOutBack.transform(
                    openController.value,
                  );

                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: AnimatedBuilder(
                        animation: effectController,
                        builder: (context, child) {
                          return _ZoomablePostcard(
                            assetPath: widget.assetPath,
                            isSpecial: widget.isSpecial,
                            progress: effectController.value,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            right: 18,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePostcard extends StatefulWidget {
  final String assetPath;
  final bool isSpecial;
  final double progress;

  const _ZoomablePostcard({
    required this.assetPath,
    required this.isSpecial,
    required this.progress,
  });

  @override
  State<_ZoomablePostcard> createState() => _ZoomablePostcardState();
}

class _ZoomablePostcardState extends State<_ZoomablePostcard> {
  double scale = 1.0;
  Offset offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          scale = details.scale.clamp(1.0, 4.0);
          offset += details.focalPointDelta;
        });
      },
      onScaleEnd: (_) {
        setState(() {
          scale = 1.0;
          offset = Offset.zero;
        });
      },
      child: Transform.translate(
        offset: offset,
        child: Transform.scale(
          scale: scale,
          child: _ExpandedPostcard(
            assetPath: widget.assetPath,
            isSpecial: widget.isSpecial,
            progress: widget.progress,
          ),
        ),
      ),
    );
  }
}

class _ExpandedPostcard extends StatelessWidget {
  final String assetPath;
  final bool isSpecial;
  final double progress;

  const _ExpandedPostcard({
    required this.assetPath,
    required this.isSpecial,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    final double maxWidth = screenSize.width < 520
        ? screenSize.width * 0.88
        : 520;

    final double cardHeight =
        maxWidth *
        _PastMediaPageState.postcardHeight /
        _PastMediaPageState.postcardWidth;

    return Container(
      width: maxWidth,
      height: cardHeight,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: isSpecial
                ? const Color(0xAA7568FF)
                : const Color(0xAA000000),
            blurRadius: isSpecial ? 38 : 25,
            spreadRadius: isSpecial ? 3 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            if (isSpecial)
              CustomPaint(painter: _ExpandedNightPainter(progress: progress)),
          ],
        ),
      ),
    );
  }
}

class _ExpandedNightPainter extends CustomPainter {
  final double progress;

  const _ExpandedNightPainter({required this.progress});

  static const List<_StarData> stars = [
    _StarData(0.10, 0.18, 3.0, 0.00),
    _StarData(0.27, 0.34, 2.0, 0.22),
    _StarData(0.75, 0.17, 2.7, 0.42),
    _StarData(0.87, 0.40, 2.0, 0.64),
    _StarData(0.18, 0.78, 2.3, 0.34),
    _StarData(0.79, 0.78, 3.0, 0.58),
    _StarData(0.52, 0.12, 1.7, 0.82),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final Paint tint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x44342B91),
          Color(0x10101845),
          Color(0x553C247D),
          Color(0x10101845),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, tint);

    final double shimmerX = -size.width + size.width * 2.4 * progress;

    final Paint shimmer = Paint()
      ..shader =
          const LinearGradient(
            colors: [
              Colors.transparent,
              Color(0x447D6CFF),
              Color(0xDDFFFFFF),
              Color(0x447D6CFF),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(shimmerX, 0, size.width * 0.65, size.height),
          );

    canvas.drawRect(rect, shimmer);

    final Paint mist = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0x004C4CE0), Color(0x334C4CE0), Color(0x004C4CE0)],
      ).createShader(rect);

    canvas.drawRect(rect, mist);

    for (final star in stars) {
      final double wave = (progress + star.phase) % 1.0;

      final double opacity = (0.15 + 0.85 * (1 - ((wave - 0.5).abs() * 2)))
          .clamp(0.1, 1.0);

      final Offset center = Offset(size.width * star.x, size.height * star.y);

      canvas.drawCircle(
        center,
        star.radius,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );

      if (star.radius >= 2.5) {
        final Paint ray = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.55)
          ..strokeWidth = 1;

        canvas.drawLine(
          Offset(center.dx - star.radius * 2.5, center.dy),
          Offset(center.dx + star.radius * 2.5, center.dy),
          ray,
        );

        canvas.drawLine(
          Offset(center.dx, center.dy - star.radius * 2.5),
          Offset(center.dx, center.dy + star.radius * 2.5),
          ray,
        );
      }
    }

    final double meteor = (progress * 1.7) % 1.0;

    if (meteor > 0.68) {
      final double t = (meteor - 0.68) / 0.32;

      final Offset end = Offset(
        size.width * (0.22 + t * 0.63),
        size.height * (0.06 + t * 0.44),
      );

      final Offset start = Offset(
        end.dx - size.width * 0.15,
        end.dy - size.height * 0.11,
      );

      final double alpha = (1 - t).clamp(0.0, 1.0);

      final Paint meteorPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0x557D6CFF),
            Colors.white.withValues(alpha: alpha),
          ],
        ).createShader(Rect.fromPoints(start, end))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, meteorPaint);

      canvas.drawCircle(
        end,
        2.8,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0x227D6CFF),
          Color(0xFFFFFFFF),
          Color(0xAA7568FF),
          Color(0x227D6CFF),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(5)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _ExpandedNightPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
