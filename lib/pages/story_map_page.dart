import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';

import '../../block/navigationbar.dart';
import '../../block/story_location_popup.dart';
import '../../block/story_task_popup.dart';
import '../../block/topbar.dart';
import 'nearby_page.dart';
import 'story_play_page.dart';
import 'story_question_page.dart';

const Color _pageColor = AppColors.background;
const Color _topColor = AppColors.paper;

const Color _daySelectedBackground = AppColors.deepRed;
const Color _daySelectedText = AppColors.paper;
const Color _dayUnselectedText = AppColors.textPrimary;

class StoryMapPage extends StatefulWidget {
  const StoryMapPage({super.key});

  @override
  State<StoryMapPage> createState() => _StoryMapPageState();
}

class _StoryMapPageState extends State<StoryMapPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;
  static const double maxScale = 1.15;
  static const double topSpacePercent = 0.05;

  int currentIndex = 1;

  int locationCurrent = 1;
  int locationTotal = 6;

  int postcardCurrent = 1;
  int postcardTotal = 10;

  int selectedDay = 1;

  bool showLocationPopup = false;
  bool showTaskPopup = false;

  String selectedLocation = '臺南孔廟';

  String selectedDescription = '臺南孔廟座落於府城歷史文化核心，建於1665年，是臺灣歷史上第一所官學。';

  final List<MapLocation> locations = const [
    MapLocation(
      id: 'location_1',
      order: 1,
      name: '臺南孔廟',
      description: '臺南孔廟座落於府城歷史文化核心，建於1665年，是臺灣歷史上第一所官學。',
      imagePath: 'img/mapok.png',
      unlocked: true,
      current: true,
    ),
    MapLocation(
      id: 'location_2',
      order: 2,
      name: '赤崁樓',
      description: '赤崁樓是臺南重要歷史古蹟，見證府城悠久的城市發展與歷史變遷。',
      imagePath: 'img/mapok.png',
      unlocked: true,
      current: false,
    ),
    MapLocation(
      id: 'location_3',
      order: 3,
      name: '神農街',
      description: '神農街保留臺南老街的歷史風貌，街區中可以感受到傳統府城生活的痕跡。',
      imagePath: 'img/mapok.png',
      unlocked: true,
      current: false,
    ),
    MapLocation(
      id: 'location_4',
      order: 4,
      name: '安平古堡',
      description: '安平古堡擁有深厚的歷史背景，是臺南最具代表性的歷史遺跡之一。',
      imagePath: 'img/mapno.png',
      unlocked: false,
      current: false,
    ),
    MapLocation(
      id: 'location_5',
      order: 5,
      name: '安平樹屋',
      description: '安平樹屋充滿特殊的歷史氛圍，老榕樹與古老建築交織出獨特景觀。',
      imagePath: 'img/mapno.png',
      unlocked: false,
      current: false,
    ),
    MapLocation(
      id: 'location_6',
      order: 6,
      name: '漁光島',
      description: '漁光島擁有自然海岸景觀，是這段旅程最後可以抵達的目的地。',
      imagePath: 'img/mapno.png',
      unlocked: false,
      current: false,
    ),
  ];

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

  double _getScale(double width, double height) {
    return AppResponsive.scale(
      availableWidth: width,
      availableHeight: height,
      designWidth: designWidth,
      designHeight: designHeight,
      max: maxScale,
    );
  }

  void openConfuciusTemple() {
    setState(() {
      selectedLocation = '臺南孔廟';
      selectedDescription = '臺南孔廟座落於府城歷史文化核心，建於1665年，是臺灣歷史上第一所官學。';
      showLocationPopup = true;
      showTaskPopup = false;
    });
  }

  void openLocation(MapLocation location) {
    if (!location.unlocked) {
      return;
    }

    setState(() {
      selectedLocation = location.name;
      selectedDescription = location.description;
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
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.storyBackground,
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

            final double topOffset = screenHeight * topSpacePercent;

            final double actualTopBarWidth = topBarDesignWidth * scale;

            final double actualTopBarHeight = topBarDesignHeight * scale;

            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: topOffset,
                  child: const ColoredBox(color: _topColor),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: topOffset,
                  height: actualTopBarHeight,
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
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: topOffset + actualTopBarHeight + 2,
                  bottom: 0,
                  child: _MapViewport(
                    locations: locations,
                    explorationProgress: 0.43,
                    onLocationTap: openLocation,
                  ),
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

class MapLocation {
  final String id;
  final int order;
  final String name;
  final String description;
  final String imagePath;
  final bool unlocked;
  final bool current;

  const MapLocation({
    required this.id,
    required this.order,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.unlocked,
    required this.current,
  });
}

class MapLocationPosition {
  final MapLocation location;
  final Offset center;

  const MapLocationPosition({required this.location, required this.center});
}

class MapLayout {
  final double width;
  final double height;
  final List<MapLocationPosition> locations;

  const MapLayout({
    required this.width,
    required this.height,
    required this.locations,
  });
}

class MapLayoutGenerator {
  static const double minMapHeight = 900;
  static const double topPadding = 150;
  static const double bottomPadding = 130;
  static const double baseVerticalSpacing = 116;
  static const double locationWidth = 150;
  static const double locationHeight = 180;
  static const double imageSize = 128;
  static const double horizontalSafeMargin = 10;
  static const double minimumHorizontalDistance = 84;

  static MapLayout generate({
    required double width,
    required List<MapLocation> locations,
    int seed = 2718,
  }) {
    if (locations.isEmpty) {
      return MapLayout(width: width, height: minMapHeight, locations: const []);
    }

    final double horizontalLimit = math.max(
      0,
      width / 2 - locationWidth / 2 - horizontalSafeMargin,
    );

    final double spacing = math.max(baseVerticalSpacing, width * 0.285);

    final double calculatedHeight =
        topPadding + ((locations.length - 1) * spacing) + bottomPadding;

    final double mapHeight = math.max(minMapHeight, calculatedHeight);

    final math.Random random = math.Random(seed);

    final List<MapLocationPosition> result = [];

    double? previousX;

    for (int index = 0; index < locations.length; index++) {
      final bool rightSide = index.isEven;

      final double sideDistance = math.min(
        horizontalLimit,
        width * 0.13 + random.nextDouble() * width * 0.022,
      );

      final double naturalOffset = (random.nextDouble() - 0.5) * width * 0.055;

      double x =
          width / 2 +
          (rightSide ? sideDistance : -sideDistance) +
          naturalOffset;

      final double minX = horizontalSafeMargin + locationWidth / 2;

      final double maxX = width - horizontalSafeMargin - locationWidth / 2;

      x = x.clamp(minX, maxX).toDouble();

      if (previousX != null &&
          (x - previousX).abs() < minimumHorizontalDistance) {
        final double direction = x >= width / 2 ? 1.0 : -1.0;

        x += direction * (minimumHorizontalDistance - (x - previousX).abs());
      }

      x = x.clamp(minX, maxX).toDouble();

      result.add(
        MapLocationPosition(
          location: locations[index],
          center: Offset(x, topPadding + index * spacing),
        ),
      );

      previousX = x;
    }

    return MapLayout(width: width, height: mapHeight, locations: result);
  }
}

class _MapViewport extends StatelessWidget {
  final List<MapLocation> locations;
  final double explorationProgress;
  final ValueChanged<MapLocation> onLocationTap;

  const _MapViewport({
    required this.locations,
    required this.explorationProgress,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final MapLayout layout = MapLayoutGenerator.generate(
          width: constraints.maxWidth,
          locations: locations,
        );

        return ClipRect(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: layout.width,
              height: layout.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(child: _TreasureMapBackground()),
                  Positioned.fill(
                    child: _TreasureRouteLayer(locations: layout.locations),
                  ),
                  Positioned.fill(
                    child: _FootprintLayer(locations: layout.locations),
                  ),
                  ...layout.locations
                      .where((item) => !item.location.unlocked)
                      .map((item) {
                        final double left =
                            item.center.dx -
                            MapLayoutGenerator.locationWidth / 2;

                        final double top =
                            item.center.dy -
                            MapLayoutGenerator.locationHeight / 2;

                        return Positioned(
                          left: left,
                          top: top,
                          width: MapLayoutGenerator.locationWidth,
                          height: MapLayoutGenerator.locationHeight,
                          child: _LockedLocationWidget(location: item.location),
                        );
                      }),
                  Positioned.fill(
                    child: _TreasureFogLayer(
                      explorationProgress: explorationProgress,
                    ),
                  ),
                  ...layout.locations
                      .where((item) => item.location.unlocked)
                      .map((item) {
                        final double left =
                            item.center.dx -
                            MapLayoutGenerator.locationWidth / 2;

                        final double top =
                            item.center.dy -
                            MapLayoutGenerator.locationHeight / 2;

                        return Positioned(
                          left: left,
                          top: top,
                          width: MapLayoutGenerator.locationWidth,
                          height: MapLayoutGenerator.locationHeight,
                          child: _MapLocationWidget(
                            location: item.location,
                            onTap: () {
                              onLocationTap(item.location);
                            },
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TreasureMapBackground extends StatelessWidget {
  const _TreasureMapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TreasureMapBackgroundPainter());
  }
}

class _TreasureMapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paperPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFAC9068),
          Color(0xFFC0A577),
          Color(0xFFA98B63),
          Color(0xFFB89A6E),
        ],
        stops: [0.0, 0.30, 0.69, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paperPaint);

    final math.Random random = math.Random(482937);

    final Paint stainPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    for (int i = 0; i < 62; i++) {
      final double x = random.nextDouble() * size.width;

      final double y = random.nextDouble() * size.height;

      final double width = 32 + random.nextDouble() * 150;

      final double height = 18 + random.nextDouble() * 105;

      stainPaint.color = i.isEven
          ? Color.fromRGBO(61, 42, 25, 0.02 + random.nextDouble() * 0.045)
          : Color.fromRGBO(242, 220, 180, 0.018 + random.nextDouble() * 0.035);

      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: width, height: height),
        stainPaint,
      );
    }

    final Paint fiberPaint = Paint()
      ..color = const Color(0x214A3322)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.42;

    for (int i = 0; i < 850; i++) {
      final double x = random.nextDouble() * size.width;

      final double y = random.nextDouble() * size.height;

      final double length = 1.4 + random.nextDouble() * 6.5;

      final double angle = -0.24 + random.nextDouble() * 0.48;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(angle) * length, y + math.sin(angle) * length),
        fiberPaint,
      );
    }

    final Paint terrainPaint = Paint()
      ..color = const Color(0x1B493322)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int i = 0; i < 20; i++) {
      final double baseY = size.height * (0.08 + i * 0.047);

      final Path path = Path()..moveTo(-20, baseY);

      for (int j = 0; j < 8; j++) {
        final double x = size.width * j / 7 + 7;

        final double y = baseY + math.sin(j * 1.05 + i * 0.71) * (4 + i % 4);

        path.lineTo(x, y);
      }

      canvas.drawPath(path, terrainPaint);
    }

    final Paint vignette = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x00000000), Color(0x15000000), Color(0x58332217)],
            stops: [0.40, 0.73, 1.0],
          ).createShader(
            Rect.fromLTWH(
              -size.width * 0.16,
              -size.height * 0.05,
              size.width * 1.32,
              size.height * 1.10,
            ),
          );

    canvas.drawRect(Offset.zero & size, vignette);

    final Paint borderPaint = Paint()
      ..color = const Color(0x36412B1D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45;

    canvas.drawRect(
      Rect.fromLTWH(
        4,
        4,
        math.max(0, size.width - 8),
        math.max(0, size.height - 8),
      ),
      borderPaint,
    );

    final Offset compassCenter = Offset(size.width - 45, 59);

    final Paint compassPaint = Paint()
      ..color = const Color(0x70452F20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;

    canvas.drawCircle(compassCenter, 20, compassPaint);

    canvas.drawCircle(compassCenter, 6, compassPaint);

    canvas.drawLine(
      compassCenter.translate(0, -16),
      compassCenter.translate(0, 16),
      compassPaint,
    );

    canvas.drawLine(
      compassCenter.translate(-16, 0),
      compassCenter.translate(16, 0),
      compassPaint,
    );

    final TextPainter compassText = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0x74452F20),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    compassText.paint(
      canvas,
      Offset(compassCenter.dx - compassText.width / 2, compassCenter.dy - 31),
    );
  }

  @override
  bool shouldRepaint(covariant _TreasureMapBackgroundPainter oldDelegate) {
    return false;
  }
}

class _TreasureRouteLayer extends StatelessWidget {
  final List<MapLocationPosition> locations;

  const _TreasureRouteLayer({required this.locations});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TreasureRoutePainter(locations: locations));
  }
}

class _TreasureRoutePainter extends CustomPainter {
  final List<MapLocationPosition> locations;

  const _TreasureRoutePainter({required this.locations});

  Path _createRoutePath(Size size, Offset start, Offset end, int index) {
    final double direction = index.isEven ? 1.0 : -1.0;

    final double curveAmount = size.width * 0.075;

    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + curveAmount * direction,
        start.dy + (end.dy - start.dy) * 0.25,
        end.dx + curveAmount * direction,
        end.dy - (end.dy - start.dy) * 0.25,
        end.dx,
        end.dy,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (locations.length < 2) {
      return;
    }

    final Paint routePaint = Paint()
      ..color = const Color(0x92553A25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, size.width / 360 * 0.82)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < locations.length - 1; i++) {
      final Path path = _createRoutePath(
        size,
        locations[i].center,
        locations[i + 1].center,
        i,
      );

      _drawDashedPath(canvas, path, routePaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashLength = 4.7;
    const double gapLength = 7.4;

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final double end = math.min(metric.length, distance + dashLength);

        canvas.drawPath(metric.extractPath(distance, end), paint);

        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreasureRoutePainter oldDelegate) {
    return oldDelegate.locations != locations;
  }
}

class _FootprintLayer extends StatelessWidget {
  final List<MapLocationPosition> locations;

  const _FootprintLayer({required this.locations});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FootprintPainter(locations: locations));
  }
}

class _FootprintPainter extends CustomPainter {
  final List<MapLocationPosition> locations;

  const _FootprintPainter({required this.locations});

  Path _createRoutePath(Size size, Offset start, Offset end, int index) {
    final double direction = index.isEven ? 1.0 : -1.0;

    final double curveAmount = size.width * 0.075;

    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + curveAmount * direction,
        start.dy + (end.dy - start.dy) * 0.25,
        end.dx + curveAmount * direction,
        end.dy - (end.dy - start.dy) * 0.25,
        end.dx,
        end.dy,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (locations.length < 2) {
      return;
    }

    final Paint footprintPaint = Paint()
      ..color = const Color(0x72513925)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < locations.length - 1; i++) {
      final Path path = _createRoutePath(
        size,
        locations[i].center,
        locations[i + 1].center,
        i,
      );

      for (final PathMetric metric in path.computeMetrics()) {
        const double startPadding = 70;

        const double endPadding = 76;

        final double usableLength = metric.length - startPadding - endPadding;

        if (usableLength <= 40) {
          continue;
        }

        final int count = math.max(2, (usableLength / 46).floor());

        final double spacing = usableLength / (count + 1);

        for (int j = 1; j <= count; j++) {
          final double distance = startPadding + spacing * j;

          final Tangent? tangent = metric.getTangentForOffset(
            distance.clamp(0, metric.length),
          );

          if (tangent == null) {
            continue;
          }

          final Tangent? before = metric.getTangentForOffset(
            math.max(0, distance - 5),
          );

          final Tangent? after = metric.getTangentForOffset(
            math.min(metric.length, distance + 5),
          );

          final Offset p1 = before?.position ?? tangent.position;

          final Offset p2 = after?.position ?? tangent.position;

          final double pathAngle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);

          final double normalX = -math.sin(pathAngle);

          final double normalY = math.cos(pathAngle);

          final double side = j.isEven ? 1.0 : -1.0;

          final double sideDistance = 16 + (j % 2) * 2.2;

          final Offset position =
              tangent.position +
              Offset(
                normalX * sideDistance * side,
                normalY * sideDistance * side,
              );

          _drawFootprint(canvas, position, pathAngle, footprintPaint);
        }
      }
    }
  }

  void _drawFootprint(
    Canvas canvas,
    Offset position,
    double pathAngle,
    Paint paint,
  ) {
    canvas.save();

    canvas.translate(position.dx, position.dy);

    canvas.rotate(pathAngle);

    final Path sole = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(0, 4), width: 4.6, height: 10.5),
      );

    canvas.drawPath(sole, paint);

    canvas.drawCircle(const Offset(-2.1, -1.8), 1.7, paint);

    canvas.drawCircle(const Offset(0, -3.2), 1.6, paint);

    canvas.drawCircle(const Offset(2.1, -1.7), 1.45, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FootprintPainter oldDelegate) {
    return oldDelegate.locations != locations;
  }
}

class _TreasureFogLayer extends StatefulWidget {
  final double explorationProgress;

  const _TreasureFogLayer({required this.explorationProgress});

  @override
  State<_TreasureFogLayer> createState() => _TreasureFogLayerState();
}

class _TreasureFogLayerState extends State<_TreasureFogLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _TreasureFogPainter(
            progress: widget.explorationProgress.clamp(0.0, 1.0).toDouble(),
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class _TreasureFogPainter extends CustomPainter {
  final double progress;
  final double animationValue;

  const _TreasureFogPainter({
    required this.progress,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) {
      return;
    }

    final Path fogArea = _buildFogArea(size, progress, animationValue);

    canvas.save();

    canvas.clipPath(fogArea);

    _drawDeepFogLayer(canvas, size, progress, animationValue);

    _drawLargeCloudBanks(canvas, size, progress, animationValue);

    _drawMiddleCloudBanks(canvas, size, progress, animationValue);

    _drawThinCloudBands(canvas, size, progress, animationValue);

    _drawWispyClouds(canvas, size, progress, animationValue);

    canvas.restore();

    _drawSoftBoundaryMist(canvas, size, progress, animationValue);
  }

  Path _buildBoundaryPath(Size size, double progress, double animation) {
    final double baseY = size.height * progress;

    const int segments = 48;

    final List<Offset> points = [];

    for (int i = 0; i <= segments; i++) {
      final double x = size.width * i / segments;

      final double waveLarge =
          math.sin(i * 0.39 + animation * math.pi * 2) * size.width * 0.075;

      final double waveMedium =
          math.sin(i * 0.91 - animation * math.pi * 2 * 0.72) *
          size.width *
          0.043;

      final double waveSmall =
          math.sin(i * 2.18 + animation * math.pi * 0.55) * size.width * 0.019;

      final double naturalWave =
          math.cos(i * 0.23 + animation * math.pi * 2.5) * size.width * 0.025;

      points.add(
        Offset(x, baseY + waveLarge + waveMedium + waveSmall + naturalWave),
      );
    }

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final Offset p0 = points[i - 1];

      final Offset p1 = points[i];

      final Offset midpoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);

      path.quadraticBezierTo(p0.dx, p0.dy, midpoint.dx, midpoint.dy);
    }

    path.lineTo(points.last.dx, points.last.dy);

    return path;
  }

  Path _buildFogArea(Size size, double progress, double animation) {
    final Path path = _buildBoundaryPath(size, progress, animation);

    path.lineTo(size.width, size.height);

    path.lineTo(0, size.height);

    path.close();

    return path;
  }

  void _drawDeepFogLayer(
    Canvas canvas,
    Size size,
    double progress,
    double animation,
  ) {
    final double top = size.height * progress;

    final Paint paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x0C5D625F),
              Color(0x525B605C),
              Color(0x8D656A66),
              Color(0xB6767B76),
            ],
            stops: const [0.0, 0.16, 0.46, 1.0],
          ).createShader(
            Rect.fromLTWH(
              0,
              top - size.height * 0.12,
              size.width,
              size.height - top + size.height * 0.12,
            ),
          );

    canvas.drawRect(
      Rect.fromLTWH(0, top - size.height * 0.16, size.width, size.height),
      paint,
    );
  }

  void _drawLargeCloudBanks(
    Canvas canvas,
    Size size,
    double progress,
    double animation,
  ) {
    _drawCloudGroup(
      canvas,
      size,
      progress,
      animation,
      seed: 181,
      count: 22,
      widthMin: 0.20,
      widthMax: 0.48,
      heightMin: 75,
      heightMax: 165,
      opacityMin: 0.10,
      opacityMax: 0.22,
      blur: 40,
      speedMin: 0.18,
      speedMax: 0.45,
      colorMode: 0,
    );
  }

  void _drawMiddleCloudBanks(
    Canvas canvas,
    Size size,
    double progress,
    double animation,
  ) {
    _drawCloudGroup(
      canvas,
      size,
      progress,
      animation,
      seed: 772,
      count: 42,
      widthMin: 0.08,
      widthMax: 0.24,
      heightMin: 34,
      heightMax: 94,
      opacityMin: 0.07,
      opacityMax: 0.17,
      blur: 25,
      speedMin: 0.36,
      speedMax: 0.78,
      colorMode: 1,
    );
  }

  void _drawThinCloudBands(
    Canvas canvas,
    Size size,
    double progress,
    double animation,
  ) {
    _drawCloudGroup(
      canvas,
      size,
      progress,
      animation,
      seed: 4019,
      count: 52,
      widthMin: 0.035,
      widthMax: 0.13,
      heightMin: 18,
      heightMax: 55,
      opacityMin: 0.045,
      opacityMax: 0.12,
      blur: 17,
      speedMin: 0.58,
      speedMax: 1.12,
      colorMode: 2,
    );
  }

  void _drawCloudGroup(
    Canvas canvas,
    Size size,
    double progress,
    double animation, {
    required int seed,
    required int count,
    required double widthMin,
    required double widthMax,
    required double heightMin,
    required double heightMax,
    required double opacityMin,
    required double opacityMax,
    required double blur,
    required double speedMin,
    required double speedMax,
    required int colorMode,
  }) {
    final math.Random random = math.Random(seed);

    final double fogTop = size.height * progress;

    for (int i = 0; i < count; i++) {
      final double depth = random.nextDouble();

      final double x = random.nextDouble() * size.width;

      final double y = fogTop + depth * (size.height - fogTop);

      final double width =
          size.width * (widthMin + random.nextDouble() * (widthMax - widthMin));

      final double height =
          heightMin + random.nextDouble() * (heightMax - heightMin);

      final double speed =
          speedMin + random.nextDouble() * (speedMax - speedMin);

      final double phase = random.nextDouble() * math.pi * 2;

      final double driftX =
          math.sin(animation * math.pi * 2 * speed + phase) *
          (14 + random.nextDouble() * 38);

      final double driftY =
          math.cos(animation * math.pi * 2 * speed * 0.45 + phase) *
          (4 + random.nextDouble() * 14);

      final double opacity =
          opacityMin + random.nextDouble() * (opacityMax - opacityMin);

      final Color color;

      switch (colorMode) {
        case 0:
          color = Color.fromRGBO(77, 82, 79, opacity);
          break;
        case 1:
          color = Color.fromRGBO(156, 161, 155, opacity);
          break;
        default:
          color = Color.fromRGBO(213, 214, 208, opacity);
      }

      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + driftX, y + driftY),
          width: width,
          height: height,
        ),
        paint,
      );
    }
  }

  void _drawWispyClouds(
    Canvas canvas,
    Size size,
    double progress,
    double animation,
  ) {
    final math.Random random = math.Random(92113);

    final double fogTop = size.height * progress;

    for (int i = 0; i < 36; i++) {
      final double x = random.nextDouble() * size.width;

      final double y = fogTop + random.nextDouble() * (size.height - fogTop);

      final double width = 70 + random.nextDouble() * 160;

      final double height = 12 + random.nextDouble() * 32;

      final double speed = 0.25 + random.nextDouble() * 0.85;

      final double phase = random.nextDouble() * math.pi * 2;

      final double drift =
          math.sin(animation * math.pi * 2 * speed + phase) * 42;

      final Paint paint = Paint()
        ..color = Color.fromRGBO(
          227,
          226,
          217,
          0.025 + random.nextDouble() * 0.08,
        )
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 21);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + drift, y),
          width: width,
          height: height,
        ),
        paint,
      );
    }
  }

  void _drawSoftBoundaryMist(
    Canvas canvas,
    Size size,
    double progress,
    double animation,
  ) {
    final Path boundary = _buildBoundaryPath(size, progress, animation);

    final Paint mist1 = Paint()
      ..color = const Color(0x385D625E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 52
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);

    canvas.drawPath(boundary, mist1);

    final Paint mist2 = Paint()
      ..color = const Color(0x2E888C86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 80
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48);

    canvas.drawPath(boundary, mist2);

    final Paint mist3 = Paint()
      ..color = const Color(0x20E1DFD5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 27);

    canvas.drawPath(boundary, mist3);
  }

  @override
  bool shouldRepaint(covariant _TreasureFogPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue;
  }
}

class _MapLocationWidget extends StatefulWidget {
  final MapLocation location;
  final VoidCallback onTap;

  const _MapLocationWidget({required this.location, required this.onTap});

  @override
  State<_MapLocationWidget> createState() => _MapLocationWidgetState();
}

class _MapLocationWidgetState extends State<_MapLocationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    if (widget.location.current) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MapLocationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.location.current && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    if (!widget.location.current && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double scale = widget.location.current
                ? 1.0 + _controller.value * 0.025
                : 1.0;

            return Transform.scale(
              scale: scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left:
                        (MapLayoutGenerator.locationWidth -
                            MapLayoutGenerator.imageSize) /
                        2,
                    top: 0,
                    child: Image.asset(
                      widget.location.imagePath,
                      width: MapLayoutGenerator.imageSize,
                      height: MapLayoutGenerator.imageSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox();
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: MapLayoutGenerator.imageSize + 2,
                    child: _LocationName(
                      location: widget.location,
                      animationValue: _controller.value,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LockedLocationWidget extends StatelessWidget {
  final MapLocation location;

  const _LockedLocationWidget({required this.location});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.84,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left:
                  (MapLayoutGenerator.locationWidth -
                      MapLayoutGenerator.imageSize) /
                  2,
              top: 0,
              child: Image.asset(
                location.imagePath,
                width: MapLayoutGenerator.imageSize,
                height: MapLayoutGenerator.imageSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox();
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: MapLayoutGenerator.imageSize + 2,
              child: _LocationName(location: location),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationName extends StatelessWidget {
  final MapLocation location;
  final double animationValue;

  const _LocationName({required this.location, this.animationValue = 0});

  Widget _nameContainer() {
    return Container(
      constraints: const BoxConstraints(minWidth: 86, maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD6D8C4A4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x6D462F21), width: 0.8),
      ),
      child: Text(
        '${location.order}. ${location.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTextStyles.captionBold.copyWith(
          color: const Color(0xFF402A1D),
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!location.current) {
      return Center(child: _nameContainer());
    }

    final double markerOpacity = 0.10 + animationValue * 0.13;

    final double markerScale = 0.96 + animationValue * 0.06;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.scale(
            scale: markerScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(markerOpacity),
                  ),
                ),
                Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD82018),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x38000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          _nameContainer(),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onDayChanged;

  const _DaySelector({required this.selectedDay, required this.onDayChanged});

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
              ),
              const SizedBox(width: 7),
              _DayButton(
                text: '第二日',
                selected: selectedDay == 2,
                onTap: () {
                  onDayChanged(2);
                },
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

  const _DayButton({
    required this.text,
    required this.selected,
    required this.onTap,
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
              style: AppTextStyles.captionBold.copyWith(
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
