import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _paperColor = AppColors.paper;
const Color _shadowColor = AppColors.deepRed;

const Color _darkText = AppColors.textPrimary;
const Color _lockedColor = Color(0xFF82766F);
const Color _lockedBorder = AppColors.dangerDark;
const Color _badgeBorder = AppColors.postcardLine;

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  static const int currentIndex = 2;

  final List<_BadgeSeries> series = [
    _BadgeSeries(
      icon: '🏛',
      title: '台灣古蹟系列',
      unlocked: 1,
      total: 10,
      expanded: true,
    ),
    _BadgeSeries(
      icon: '🌲',
      title: '山海寶島系列',
      unlocked: 1,
      total: 10,
      expanded: false,
    ),
    _BadgeSeries(
      icon: '🌲',
      title: '山海寶島系列',
      unlocked: 1,
      total: 10,
      expanded: false,
    ),
    _BadgeSeries(
      icon: '🌲',
      title: '山海寶島系列',
      unlocked: 1,
      total: 10,
      expanded: false,
    ),
    _BadgeSeries(
      icon: '🌲',
      title: '山海寶島系列',
      unlocked: 1,
      total: 10,
      expanded: false,
    ),
    _BadgeSeries(
      icon: '🌲',
      title: '山海寶島系列',
      unlocked: 1,
      total: 10,
      expanded: false,
    ),
    _BadgeSeries(
      icon: '🌲',
      title: '山海寶島系列',
      unlocked: 1,
      total: 10,
      expanded: false,
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
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  void toggleSeries(int index) {
    setState(() {
      series[index] = series[index].copyWith(expanded: !series[index].expanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,

      body: ScrollConfiguration(
        behavior: const _NoScrollbarBehavior(),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),

          padding: EdgeInsets.fromLTRB(
            15,
            55,
            15,
            100 + MediaQuery.of(context).padding.bottom,
          ),

          itemCount: series.length,

          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BadgeSeriesCard(
                series: series[index],
                onTap: () {
                  toggleSeries(index);
                },
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: const AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

class _BadgeSeriesCard extends StatefulWidget {
  final _BadgeSeries series;
  final VoidCallback onTap;

  const _BadgeSeriesCard({
    required this.series,
    required this.onTap,
  });

  @override
  State<_BadgeSeriesCard> createState() => _BadgeSeriesCardState();
}

class _BadgeSeriesCardState extends State<_BadgeSeriesCard> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool expanded = widget.series.expanded;

    final double scale = pressing ? 0.985 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 4,
              right: -4,
              top: 5,
              bottom: expanded ? 5 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _shadowColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(
                color: _paperColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.series.icon,
                        style: AppTextStyles.sectionTitle.copyWith(height: 1.0),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyEmphasisBold.copyWith(color: _darkText),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.series.unlocked}/${widget.series.total}',
                        style: AppTextStyles.bodySmallBold.copyWith(color: _darkText),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 0),
                            child: _BadgeGrid(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
const _BadgeGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 10,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return _BadgeItem(
          unlocked: index == 0,
          name: index == 0 ? '台灣古蹟' : '未解鎖',
);
      },
    );
  }
}

class _BadgeItem extends StatefulWidget {
  final bool unlocked;
  final String name;
  const _BadgeItem({
    required this.unlocked,
    required this.name,
});

  @override
  State<_BadgeItem> createState() => _BadgeItemState();
}

class _BadgeItemState extends State<_BadgeItem> {
  bool pressing = false;

  void _showBadge() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Badge',

      barrierColor: Colors.black.withOpacity(0.72),

      transitionDuration: const Duration(milliseconds: 300),

      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return _BadgePopup(
              unlocked: widget.unlocked,
              name: widget.name,
);
          },

      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            );

            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.55,
                  end: 1.0,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: _showBadge,

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
        scale: pressing ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,

        child: widget.unlocked ? const _UnlockedBadge() : const _LockedBadge(),
      ),
    );
  }
}

class _BadgePopup extends StatelessWidget {
  final bool unlocked;
  final String name;
  const _BadgePopup({
    required this.unlocked,
    required this.name,
});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: () {
          Navigator.of(context).pop();
        },

        child: Center(
          child: GestureDetector(
            onTap: () {},

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: unlocked
                      ? const _UnlockedBadge()
                      : const _LockedBadge(),
                ),

                const SizedBox(height: 18),

                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockedBadge extends StatelessWidget {
  const _UnlockedBadge();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BadgeDashedBorderPainter(),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE6D8AB),
          boxShadow: [
            BoxShadow(
              color: Color(0x35000000),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _badgeBorder, width: 1.3),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: Image.asset(
              'img/Badge_location.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedBadge extends StatelessWidget {
  const _LockedBadge();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BadgeDashedBorderPainter(),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _lockedColor,
          boxShadow: [
            BoxShadow(
              color: Color(0x45000000),
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeDashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 1;

    final Paint paint = Paint()
      ..color = _lockedBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const double dashLength = 4.0;
    const double gapLength = 3.5;

    final double circumference = 2 * math.pi * radius;

    final int count = (circumference / (dashLength + gapLength)).floor();

    if (count <= 0) {
      return;
    }

    final double step = 2 * math.pi / count;

    for (int i = 0; i < count; i++) {
      final double start = i * step;

      final double sweep = step * (dashLength / (dashLength + gapLength));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeDashedBorderPainter oldDelegate) {
    return false;
  }
}

class _BadgeSeries {
  final String icon;
  final String title;
  final int unlocked;
  final int total;
  final bool expanded;

  const _BadgeSeries({
    required this.icon,
    required this.title,
    required this.unlocked,
    required this.total,
    required this.expanded,
  });

  _BadgeSeries copyWith({
    String? icon,
    String? title,
    int? unlocked,
    int? total,
    bool? expanded,
  }) {
    return _BadgeSeries(
      icon: icon ?? this.icon,
      title: title ?? this.title,
      unlocked: unlocked ?? this.unlocked,
      total: total ?? this.total,
      expanded: expanded ?? this.expanded,
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

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
