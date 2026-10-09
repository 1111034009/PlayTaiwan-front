import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';

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

  List<_BadgeSeries> series = [];

  bool isLoading = true;

  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

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

    _loadBadgeStatus();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadBadgeStatus() async {
    final token = AppSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('登入資訊已失效，請重新登入');
      return;
    }

    if (_apiBaseUrl.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('API_BASE_URL 未設定');
      return;
    }

    try {
      final Uri uri = Uri.parse('$_apiBaseUrl/api/Badge/Status');

      final response = await http.get(
        uri,
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showMessage('登入資訊已失效，請重新登入');
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showMessage('取得徽章資料失敗');
        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('API 回傳格式錯誤');
      }

      final bool isSuccess = decoded['isSuccess'] == true;

      final String message = decoded['message']?.toString() ?? '取得徽章資料失敗';

      if (!isSuccess) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showMessage(message);
        return;
      }

      final dynamic rawResult = decoded['Result'];

      if (rawResult is! List) {
        throw Exception('徽章 Result 格式錯誤');
      }

      final List<_BadgeSeries> loadedSeries = [];

      for (int i = 0; i < rawResult.length; i++) {
        final dynamic rawSeries = rawResult[i];

        if (rawSeries is! Map<String, dynamic>) {
          continue;
        }

        final String seriesId = rawSeries['series_id']?.toString() ?? '';

        final String seriesName =
            rawSeries['series_name']?.toString() ?? '未命名系列';

        final List<_Badge> badges = [];

        final dynamic rawBadges = rawSeries['badges'];

        if (rawBadges is List) {
          for (final dynamic rawBadge in rawBadges) {
            if (rawBadge is Map<String, dynamic>) {
              badges.add(_Badge.fromJson(rawBadge));
            }
          }
        }

        loadedSeries.add(
          _BadgeSeries(
            seriesId: seriesId,
            title: seriesName,
            badges: badges,

            expanded: i == 0,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        series = loadedSeries;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('取得徽章資料失敗，請稍後再試');
    }
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

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : series.isEmpty
          ? _buildEmptyState()
          : ScrollConfiguration(
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 56,
              color: _lockedColor,
            ),
            const SizedBox(height: 15),
            Text(
              '目前沒有徽章資料',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyEmphasisBold.copyWith(color: _darkText),
            ),
            const SizedBox(height: 8),
            Text(
              '完成任務後就可以獲得徽章喔！',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: _lockedColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeSeriesCard extends StatefulWidget {
  final _BadgeSeries series;
  final VoidCallback onTap;

  const _BadgeSeriesCard({required this.series, required this.onTap});

  @override
  State<_BadgeSeriesCard> createState() => _BadgeSeriesCardState();
}

class _BadgeSeriesCardState extends State<_BadgeSeriesCard> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool expanded = widget.series.expanded;
    final bool isMidnightTaiwan = widget.series.title.trim() == '🌙 午夜台灣';
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
                      Expanded(
                        child: Text(
                          widget.series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyEmphasisBold.copyWith(
                            color: _darkText,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        '${widget.series.unlocked}/${widget.series.total}',
                        style: AppTextStyles.bodySmallBold.copyWith(
                          color: _darkText,
                        ),
                      ),
                    ],
                  ),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,

                    child: expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _BadgeGrid(
                              badges: widget.series.badges,
                              isMidnight: isMidnightTaiwan,
                            ),
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
  final List<_Badge> badges;
  final bool isMidnight;

  const _BadgeGrid({required this.badges, required this.isMidnight});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: badges.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final _Badge badge = badges[index];

        return _BadgeItem(badge: badge, isMidnight: isMidnight);
      },
    );
  }
}

class _BadgeItem extends StatefulWidget {
  final _Badge badge;
  final bool isMidnight;

  const _BadgeItem({required this.badge, required this.isMidnight});

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
      barrierColor: Colors.black.withOpacity(0.90),
      transitionDuration: const Duration(milliseconds: 300),

      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return _BadgePopup(
              badge: widget.badge,
              isMidnight: widget.isMidnight,
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

        child: widget.badge.isOwned
            ? _UnlockedBadge(
                imageUrl: widget.badge.imageUrl,
                isMidnight: widget.isMidnight,
              )
            : _LockedBadge(isMidnight: widget.isMidnight),
      ),
    );
  }
}

class _BadgePopup extends StatelessWidget {
  final _Badge badge;
  final bool isMidnight;

  const _BadgePopup({required this.badge, required this.isMidnight});

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

                  child: badge.isOwned
                      ? _UnlockedBadge(
                          imageUrl: badge.imageUrl,
                          isMidnight: isMidnight,
                        )
                      : _LockedBadge(isMidnight: isMidnight),
                ),

                const SizedBox(height: 18),

                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                ),

                if (badge.description.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),

                    child: Text(
                      badge.description,
                      textAlign: TextAlign.center,

                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],

                if (badge.isOwned &&
                    badge.obtainedAt != null &&
                    badge.obtainedAt!.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  Text(
                    '獲得時間：${badge.obtainedAt}',
                    textAlign: TextAlign.center,

                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockedBadge extends StatefulWidget {
  final String? imageUrl;
  final bool isMidnight;

  const _UnlockedBadge({this.imageUrl, this.isMidnight = false});

  @override
  State<_UnlockedBadge> createState() => _UnlockedBadgeState();
}

class _UnlockedBadgeState extends State<_UnlockedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (widget.isMidnight) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMidnight) {
      return _buildBadge();
    }

    return AnimatedBuilder(
      animation: _controller,

      builder: (context, child) {
        final double glow = Curves.easeInOut.transform(_controller.value);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,

          children: [
            // 外圍藍紫色夜光
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,

                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x553B82F6),
                      const Color(0xCC8B5CF6),
                      glow,
                    )!,
                    blurRadius: 8 + (10 * glow),
                    spreadRadius: 1 + (3 * glow),
                  ),
                ],
              ),

              child: _buildBadge(),
            ),

            // 外圍星星
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MidnightStarsPainter(progress: glow),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadge() {
    return CustomPaint(
      painter: _BadgeDashedBorderPainter(isMidnight: widget.isMidnight),

      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,

          color: widget.isMidnight
              ? const Color(0xFF171A3D)
              : const Color(0xFFE6D8AB),

          boxShadow: const [
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

            border: Border.all(
              color: widget.isMidnight ? const Color(0xFF8B86FF) : _badgeBorder,
              width: 1.3,
            ),
          ),

          padding: const EdgeInsets.all(3),

          child: ClipOval(
            child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                ? Image.network(
                    widget.imageUrl!,

                    fit: BoxFit.cover,

                    filterQuality: FilterQuality.high,

                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: widget.isMidnight
                              ? Colors.white54
                              : Colors.grey,
                          size: 30,
                        ),
                      );
                    },

                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,

                          child: CircularProgressIndicator(
                            strokeWidth: 2,

                            color: widget.isMidnight
                                ? const Color(0xFF9B8CFF)
                                : null,
                          ),
                        ),
                      );
                    },
                  )
                : Image.asset('img/Badge_location.png', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _MidnightStarsPainter extends CustomPainter {
  final double progress;

  const _MidnightStarsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    const List<_MidnightStar> stars = [
      _MidnightStar(angle: -0.9, distance: 0.82, size: 2.2, phase: 0.0),
      _MidnightStar(angle: 0.15, distance: 0.88, size: 1.5, phase: 0.35),
      _MidnightStar(angle: 1.15, distance: 0.82, size: 2.0, phase: 0.7),
      _MidnightStar(angle: 2.15, distance: 0.88, size: 1.5, phase: 0.2),
      _MidnightStar(angle: 3.0, distance: 0.82, size: 2.1, phase: 0.55),
      _MidnightStar(angle: -2.25, distance: 0.87, size: 1.5, phase: 0.85),
    ];

    for (final star in stars) {
      final double opacity =
          0.25 + 0.75 * math.sin((progress + star.phase) * math.pi).abs();

      final double x =
          center.dx + math.cos(star.angle) * radius * star.distance;

      final double y =
          center.dy + math.sin(star.angle) * radius * star.distance;

      paint.color = Colors.white.withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), star.size, paint);

      // 十字型星光
      if (star.size >= 2) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(opacity * 0.5)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(x - star.size * 2, y),
          Offset(x + star.size * 2, y),
          glowPaint,
        );

        canvas.drawLine(
          Offset(x, y - star.size * 2),
          Offset(x, y + star.size * 2),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MidnightStarsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MidnightStar {
  final double angle;
  final double distance;
  final double size;
  final double phase;

  const _MidnightStar({
    required this.angle,
    required this.distance,
    required this.size,
    required this.phase,
  });
}

class _LockedBadge extends StatelessWidget {
  final bool isMidnight;

  const _LockedBadge({this.isMidnight = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BadgeDashedBorderPainter(isMidnight: isMidnight),

      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,

          color: isMidnight ? const Color(0xFF25264D) : _lockedColor,

          boxShadow: [
            BoxShadow(
              color: isMidnight
                  ? const Color(0x554F46E5)
                  : const Color(0x45000000),

              blurRadius: isMidnight ? 10 : 4,

              spreadRadius: isMidnight ? 1 : 0,

              offset: const Offset(0, 3),
            ),
          ],
        ),

        alignment: Alignment.center,

        child: Text(
          '未解鎖',

          textAlign: TextAlign.center,

          style: AppTextStyles.captionBold.copyWith(
            color: isMidnight ? const Color(0xFFC4C7FF) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BadgeDashedBorderPainter extends CustomPainter {
  final bool isMidnight;

  const _BadgeDashedBorderPainter({this.isMidnight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);

    final double radius = size.shortestSide / 2 - 1;

    final Paint paint = Paint()
      ..color = isMidnight ? const Color(0xFF8B86FF) : _lockedBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMidnight ? 1.8 : 1.5
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
    return oldDelegate.isMidnight != isMidnight;
  }
}

class _BadgeSeries {
  final String seriesId;
  final String title;
  final List<_Badge> badges;
  final bool expanded;

  const _BadgeSeries({
    required this.seriesId,
    required this.title,
    required this.badges,
    required this.expanded,
  });

  int get unlocked {
    return badges.where((badge) => badge.isOwned).length;
  }

  int get total {
    return badges.length;
  }

  _BadgeSeries copyWith({
    String? seriesId,
    String? title,
    List<_Badge>? badges,
    bool? expanded,
  }) {
    return _BadgeSeries(
      seriesId: seriesId ?? this.seriesId,
      title: title ?? this.title,
      badges: badges ?? this.badges,
      expanded: expanded ?? this.expanded,
    );
  }
}

class _Badge {
  final String badgeId;
  final String name;
  final String description;
  final String? imageUrl;
  final bool isOwned;
  final String? obtainedAt;

  const _Badge({
    required this.badgeId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.isOwned,
    required this.obtainedAt,
  });

  factory _Badge.fromJson(Map<String, dynamic> json) {
    final String imagePath = json['b_image']?.toString() ?? '';

    String? imageUrl;

    if (imagePath.isNotEmpty) {
      final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        imageUrl = imagePath;
      } else if (baseUrl.isNotEmpty) {
        imageUrl =
            '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/${imagePath.replaceFirst(RegExp(r'^/'), '')}';
      }
    }

    return _Badge(
      badgeId: json['b_id']?.toString() ?? '',
      name: json['b_name']?.toString() ?? '',
      description: json['b_thing']?.toString() ?? '',
      imageUrl: imageUrl,
      isOwned: json['is_owned'] == true,
      obtainedAt: json['obtained_at']?.toString(),
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
