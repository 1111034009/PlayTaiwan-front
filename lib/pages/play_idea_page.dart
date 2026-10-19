import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import 'travel_info_page.dart';
import '../block/navigationbar.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _resultText = AppColors.textPrimary;

const Color _wheelGoldA = Color(0xFFD8C27D);
const Color _wheelGoldB = Color(0xFFD1B973);
const Color _wheelCenter = Color(0xFFB49A2C);
const Color _wheelCenterDark = Color(0xFF49312E);
const Color _wheelLine = Color(0xFF443431);

const Color _startBorder = Color(0xFF144A06);
const Color _startCenter = Color(0xFF209B15);
const Color _startOuter = Color(0xFF1F7D07);

const Color _redrawBorder = AppColors.primaryDark;
const Color _redrawCenter = AppColors.primaryLight;
const Color _redrawOuter = AppColors.primary;

class PlayIdeaPage extends StatefulWidget {
  const PlayIdeaPage({super.key});

  @override
  State<PlayIdeaPage> createState() => _PlayIdeaPageState();
}

class _PlayIdeaPageState extends State<PlayIdeaPage>
    with SingleTickerProviderStateMixin {
  static const double designWidth = 360;
  static const double designHeight = 640;

  int currentIndex = 1;

  static const List<_Location> locations = [
    _Location(fullName: '台北市', wheelName: '台北'),
    _Location(fullName: '新北市', wheelName: '新北'),
    _Location(fullName: '桃園市', wheelName: '桃園'),
    _Location(fullName: '台中市', wheelName: '台中'),
    _Location(fullName: '台南市', wheelName: '台南'),
    _Location(fullName: '高雄市', wheelName: '高雄'),
    _Location(fullName: '基隆市', wheelName: '基隆'),
    _Location(fullName: '新竹市', wheelName: '新竹市'),
    _Location(fullName: '新竹縣', wheelName: '新竹縣'),
    _Location(fullName: '苗栗縣', wheelName: '苗栗'),
    _Location(fullName: '彰化縣', wheelName: '彰化'),
    _Location(fullName: '南投縣', wheelName: '南投'),
    _Location(fullName: '雲林縣', wheelName: '雲林'),
    _Location(fullName: '嘉義市', wheelName: '嘉義市'),
    _Location(fullName: '嘉義縣', wheelName: '嘉義縣'),
    _Location(fullName: '屏東縣', wheelName: '屏東'),
    _Location(fullName: '宜蘭縣', wheelName: '宜蘭'),
    _Location(fullName: '花蓮縣', wheelName: '花蓮'),
    _Location(fullName: '台東縣', wheelName: '台東'),
    _Location(fullName: '澎湖縣', wheelName: '澎湖'),
    _Location(fullName: '金門縣', wheelName: '金門'),
    _Location(fullName: '連江縣', wheelName: '連江'),
  ];

  late final AnimationController _wheelController;

  int? selectedIndex;
  int? pendingIndex;

  bool isSpinning = false;

  double wheelRotation = 0.0;
  double animationStartRotation = 0.0;
  double animationTargetRotation = 0.0;

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

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _wheelController.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }

      setState(() {
        wheelRotation = animationTargetRotation;
        isSpinning = false;
        selectedIndex = pendingIndex;
        pendingIndex = null;
      });

      _wheelController.reset();
    });

    // 進入頁面後自動抽一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) {
          return;
        }

        spinWheel();
      });
    });
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  // ============================================================
  // 字體
  // ============================================================
  // ============================================================
  // 轉盤
  // ============================================================

  void spinWheel() {
    if (isSpinning) {
      return;
    }

    final math.Random random = math.Random();

    final int newIndex = random.nextInt(locations.length);

    final double sectorAngle = 2 * math.pi / locations.length;

    final double targetSector = (newIndex + 0.5) * sectorAngle;

    final int fullTurns = 5 + random.nextInt(3);

    final double currentRotation = wheelRotation;

    final double twoPi = 2 * math.pi;

    double normalizedCurrent = currentRotation % twoPi;

    if (normalizedCurrent < 0) {
      normalizedCurrent += twoPi;
    }

    final double desiredRotation = -targetSector;

    final double deltaToTarget = (desiredRotation - normalizedCurrent) % twoPi;

    final double targetRotation =
        currentRotation + fullTurns * twoPi + deltaToTarget;

    setState(() {
      isSpinning = true;
      pendingIndex = newIndex;
      animationStartRotation = currentRotation;
      animationTargetRotation = targetRotation;
    });

    _wheelController.forward(from: 0);
  }

  void redraw() {
    if (isSpinning) {
      return;
    }

    spinWheel();
  }

  void goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: SizedBox.expand(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: designWidth,
                    height: designHeight,
                    child: _buildDesignPage(),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 12, 10),
                  child: Text(
                    '<< 返回',
                    style: AppTextStyles.bodySmallBold
                        .copyWith(color: const Color(0xFFFAF7F1))
                        .copyWith(
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(1.2, 1.5),
                              blurRadius: 1.5,
                            ),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  Widget _buildDesignPage() {
    return SizedBox(
      width: designWidth,
      height: designHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ======================================================
          // 背景
          // ======================================================
          Positioned.fill(child: Container(color: _pageColor)),

          // ======================================================
          // 標題
          // ======================================================
          Positioned(
            left: 0,
            right: 0,
            top: 40,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'img/user_icon_line.png',
                    width: 27,
                    height: 27,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  _OutlinedTitle(text: '來點遊意思'),
                ],
              ),
            ),
          ),

          // ======================================================
          // 副標題
          // ======================================================
          Positioned(
            left: 0,
            right: 0,
            top: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warmPaper.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF8A7163).withOpacity(0.30),
                    width: 1,
                  ),
                ),
                child: Text(
                  '轉動命運的轉盤，來點遊意思',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyEmphasisBold.copyWith(
                    color: _darkBrown,
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // 紙張背景
          // ======================================================
          Positioned(
            left: 13,
            top: 130,
            width: 334,
            height: 426,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset('img/background_papper.png', fit: BoxFit.fill),
            ),
          ),

          // ======================================================
          // 轉盤
          // ======================================================
          Positioned(
            left: 46,
            top: 155,
            width: 268,
            height: 268,
            child: AnimatedBuilder(
              animation: _wheelController,
              builder: (context, child) {
                final double progress = Curves.easeOutCubic.transform(
                  _wheelController.value,
                );

                final double currentRotation = isSpinning
                    ? animationStartRotation +
                          (animationTargetRotation - animationStartRotation) *
                              progress
                    : wheelRotation;

                return Transform.rotate(
                  angle: currentRotation,
                  child: CustomPaint(
                    size: const Size(268, 268),
                    painter: _WheelPainter(locations: locations),
                  ),
                );
              },
            ),
          ),

          // ======================================================
          // 指針
          // ======================================================
          Positioned(
            left: 159,
            top: 156,
            width: 42,
            height: 30,
            child: CustomPaint(painter: _PointerPainter()),
          ),

          Positioned(
            left: 20,
            right: 20,
            top: 430,
            height: 35,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),

              layoutBuilder: (currentChild, previousChildren) {
                return SizedBox.expand(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                );
              },

              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: child,
                  ),
                );
              },

              child: Text(
                selectedIndex == null
                    ? '準備好了嗎？'
                    : locations[selectedIndex!].fullName,
                key: ValueKey(selectedIndex),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style:
                    (selectedIndex == null
                            ? AppTextStyles.title
                            : AppTextStyles.displayLarge)
                        .copyWith(color: _resultText),
              ),
            ),
          ),

          // ======================================================
          // 重抽按鈕
          // ======================================================
          Positioned(
            left: 75,
            top: 472,
            width: 94,
            height: 45,
            child: _WheelButton(
              text: '重抽',
              borderColor: _redrawBorder,
              centerColor: _redrawCenter,
              outerColor: _redrawOuter,
              enabled: !isSpinning,
              onPressed: redraw,
            ),
          ),

          // ======================================================
          // 確認按鈕
          // ======================================================
          Positioned(
            left: 191,
            top: 472,
            width: 94,
            height: 45,
            child: _WheelButton(
              text: '確認',
              borderColor: _startBorder,
              centerColor: _startCenter,
              outerColor: _startOuter,
              enabled: !isSpinning && selectedIndex != null,
              onPressed: () {
                if (selectedIndex == null) {
                  return;
                }

                final String cityName = locations[selectedIndex!].fullName;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TravelInfoPage(cityName: cityName, townName: ''),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// Location
// ================================================================

class _Location {
  final String fullName;
  final String wheelName;

  const _Location({required this.fullName, required this.wheelName});
}

// ================================================================
// 標題
// ================================================================

class _OutlinedTitle extends StatelessWidget {
  final String text;
  const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = AppTextStyles.displayLarge
        .copyWith(color: _darkBrown)
        .copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..color = _darkBrown,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: outlineStyle),
        Text(
          text,
          style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

// ================================================================
// Wheel Painter
// ================================================================

class _WheelPainter extends CustomPainter {
  final List<_Location> locations;

  const _WheelPainter({required this.locations});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double outerRadius = size.width * 0.495;

    final double innerRadius = size.width * 0.442;

    final int segmentCount = locations.length;

    final double segmentAngle = 2 * math.pi / segmentCount;

    // ------------------------------------------------------------
    // 外框
    // ------------------------------------------------------------

    final Paint outerRing = Paint()
      ..color = _darkBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, outerRadius, outerRing);

    // ------------------------------------------------------------
    // 扇形
    // ------------------------------------------------------------

    final Rect wheelRect = Rect.fromCircle(center: center, radius: innerRadius);

    for (int i = 0; i < segmentCount; i++) {
      final double startAngle = -math.pi / 2 + i * segmentAngle;

      final Paint fill = Paint()
        ..color = i.isEven ? _wheelGoldA : _wheelGoldB
        ..style = PaintingStyle.fill;

      canvas.drawArc(wheelRect, startAngle, segmentAngle, true, fill);
    }

    // ------------------------------------------------------------
    // 內框
    // ------------------------------------------------------------

    final Paint innerRing = Paint()
      ..color = _darkBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(center, innerRadius, innerRing);

    // ------------------------------------------------------------
    // 分隔線
    // ------------------------------------------------------------

    final Paint divider = Paint()
      ..color = _wheelLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < segmentCount; i++) {
      final double angle = -math.pi / 2 + i * segmentAngle;

      final Offset end = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );

      canvas.drawLine(center, end, divider);
    }

    // ------------------------------------------------------------
    // 轉盤文字
    // ------------------------------------------------------------

    final TextStyle labelStyle = AppTextStyles.microTightBold.copyWith(
      color: _darkBrown,
    );

    final double textRadius = size.width * 0.355;

    for (int i = 0; i < segmentCount; i++) {
      final double angle = -math.pi / 2 + (i + 0.5) * segmentAngle;

      final Offset textCenter = Offset(
        center.dx + math.cos(angle) * textRadius,
        center.dy + math.sin(angle) * textRadius,
      );

      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: locations[i].wheelName, style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      );

      textPainter.layout(maxWidth: size.width * 0.19);

      canvas.save();

      canvas.translate(textCenter.dx, textCenter.dy);

      canvas.rotate(angle + math.pi / 2);

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }

    // ------------------------------------------------------------
    // 中央圓
    // ------------------------------------------------------------

    final double centerRadius = size.width * 0.127;

    final Paint centerPaint = Paint()
      ..color = _wheelCenter
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, centerRadius, centerPaint);

    // ------------------------------------------------------------
    // 中央圓框
    // ------------------------------------------------------------

    final Paint centerBorder = Paint()
      ..color = _wheelLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, centerRadius, centerBorder);

    // ------------------------------------------------------------
    // 中央深色圓點
    // ------------------------------------------------------------

    final Paint centerDot = Paint()
      ..color = _wheelCenterDark
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, size.width * 0.052, centerDot);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.locations != locations;
  }
}

// ================================================================
// Pointer Painter
// ================================================================

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path triangle = Path();

    triangle.moveTo(size.width / 2, size.height);

    triangle.lineTo(0, 0);

    triangle.lineTo(size.width, 0);

    triangle.close();

    // ------------------------------------------------------------
    // 指針填色
    // ------------------------------------------------------------

    final Paint fill = Paint()
      ..color = const Color(0xFFB92027)
      ..style = PaintingStyle.fill;

    canvas.drawPath(triangle, fill);

    // ------------------------------------------------------------
    // 指針外框
    // ------------------------------------------------------------

    final Paint border = Paint()
      ..color = const Color(0xFF5B2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(triangle, border);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) {
    return false;
  }
}

// ================================================================
// Wheel Button
// ================================================================

class _WheelButton extends StatefulWidget {
  final String text;

  final Color borderColor;
  final Color centerColor;
  final Color outerColor;

  final bool enabled;

  final VoidCallback onPressed;

  const _WheelButton({
    required this.text,
    required this.borderColor,
    required this.centerColor,
    required this.outerColor,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_WheelButton> createState() => _WheelButtonState();
}

class _WheelButtonState extends State<_WheelButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;

    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.08
        : 1.0;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,

      // ----------------------------------------------------------
      // Hover
      // ----------------------------------------------------------
      onEnter: (_) {
        if (!enabled) {
          return;
        }

        setState(() {
          hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      // ----------------------------------------------------------
      // 點擊
      // ----------------------------------------------------------
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,

        onTapDown: enabled
            ? (_) {
                setState(() {
                  pressing = true;
                });
              }
            : null,

        onTapUp: enabled
            ? (_) {
                setState(() {
                  pressing = false;
                });
              }
            : null,

        onTapCancel: () {
          setState(() {
            pressing = false;
          });
        },

        // --------------------------------------------------------
        // 按鈕動畫
        // --------------------------------------------------------
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,

          child: Container(
            width: 94,
            height: 45,

            alignment: Alignment.center,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),

              border: Border.all(color: widget.borderColor, width: 2),

              gradient: RadialGradient(
                center: const Alignment(-0.25, -0.25),
                radius: 1.15,

                colors: [
                  widget.centerColor,
                  widget.centerColor,
                  widget.outerColor,
                ],

                stops: const [0.0, 0.42, 1.0],
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
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyEmphasisBold.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
