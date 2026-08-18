import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// const Color _topColor = Color(0xFFEBE1C7);
const Color _darkText = Color(0xFF301717);

const double topBarDesignWidth = 360.0;
const double topBarDesignHeight = 70.0;

const double topBarDecorationOverflow = 18.0;

class TopBar extends StatelessWidget {
  final int locationCurrent;
  final int locationTotal;

  final int postcardCurrent;
  final int postcardTotal;

  const TopBar({
    super.key,
    required this.locationCurrent,
    required this.locationTotal,
    required this.postcardCurrent,
    required this.postcardTotal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        final double widthScale = width / topBarDesignWidth;
        final double heightScale = height / topBarDesignHeight;

        final double scale = widthScale < heightScale
            ? widthScale
            : heightScale;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -15.0 * scale,
              bottom: -18.0 * scale,
              child: IgnorePointer(
                child: Image.asset(
                  'img/Decoration.png',
                  width: 86.0 * scale,
                  height: 86.0 * scale,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return SizedBox(width: 86.0 * scale, height: 86.0 * scale);
                  },
                ),
              ),
            ),

            Positioned(
              left: 77.0 * scale,
              top: 10.0 * scale,
              child: _ProgressItem(
                scale: scale,
                iconPath: 'img/location_icon.png',
                title: '地點探索度',
                current: locationCurrent,
                total: locationTotal,
              ),
            ),

            Positioned(
              left: 208.0 * scale,
              top: 10.0 * scale,
              child: _ProgressItem(
                scale: scale,
                iconPath: 'img/postcard_icon.png',
                title: '明信片收集',
                current: postcardCurrent,
                total: postcardTotal,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final double scale;

  final String iconPath;
  final String title;

  final int current;
  final int total;

  const _ProgressItem({
    required this.scale,
    required this.iconPath,
    required this.title,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = total <= 0
        ? 0.0
        : (current / total).clamp(0.0, 1.0).toDouble();

    final double itemWidth = 115.0 * scale;

    final double iconWidth = 23.0 * scale;
    final double iconHeight = 25.0 * scale;

    final double progressWidth = 104.0 * scale;
    final double progressHeight = 8.0 * scale;

    final double titleFontSize = (14.0 * scale).clamp(10.0, 14.0).toDouble();

    final double numberFontSize = (13.0 * scale).clamp(9.0, 13.0).toDouble();

    final double titleSpacing = (4.0 * scale).clamp(2.0, 4.0).toDouble();

    return SizedBox(
      width: itemWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                iconPath,
                width: iconWidth,
                height: iconHeight,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return SizedBox(width: iconWidth, height: iconHeight);
                },
              ),

              SizedBox(width: titleSpacing),

              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: GoogleFonts.kaiseiHarunoUmi(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.only(left: 27.0 * scale, top: 2.0 * scale),
            child: Text(
              '$current/$total',
              style: GoogleFonts.kaiseiHarunoUmi(
                fontSize: numberFontSize,
                fontWeight: FontWeight.w700,
                color: _darkText,
                height: 1.0,
              ),
            ),
          ),

          SizedBox(height: 4.0 * scale),

          SizedBox(
            width: progressWidth,
            height: progressHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0 * scale),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景
                  const ColoredBox(color: Color(0xFFC5B27C)),

                  // 已完成
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF93412E),
                          borderRadius: BorderRadius.circular(20.0 * scale),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
