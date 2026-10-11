import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/merchant_vlog_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const Color _backgroundColor = AppColors.textPrimary;
const Color _lightText = AppColors.paper;
const Color _progressBackground = AppColors.paper;
const Color _progressColor = Color(0xFFC7381E);
const Color _black = Colors.black;

class VideoLoadingPage extends StatefulWidget {
  final Future<VlogPreview> Function() task;

  const VideoLoadingPage({super.key, required this.task});

  @override
  State<VideoLoadingPage> createState() => _VideoLoadingPageState();
}

class _VideoLoadingPageState extends State<VideoLoadingPage>
    with SingleTickerProviderStateMixin {
  static const double designWidth = 360;
  static const double designHeight = 640;
  static const double _holdValue = 0.99;

  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _backgroundColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _progressController = AnimationController(vsync: this)
      ..animateTo(
        _holdValue,
        duration: const Duration(seconds: 20),
        curve: Curves.easeInOut,
      );

    _run();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    Object result;

    try {
      result = await widget.task();
    } catch (e) {
      result = e;
    }

    if (!mounted) return;

    if (result is VlogPreview) {
      await _progressController.animateTo(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeIn,
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: _backgroundColor),
                  ),
                  Positioned(
                    top: 136,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 208,
                        height: 208,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x807B6D69),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'img/video_loading.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 369,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _OutlinedText(
                        text: '檔案生成中...',
                        style: AppTextStyles.heroTitle.copyWith(
                          color: _lightText,
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 431,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (_, __) {
                          final int percent = (_progressController.value * 100)
                              .floor();

                          return _OutlinedText(
                            text: 'Loading... $percent%',
                            style: AppTextStyles.title.copyWith(
                              color: _lightText,
                            ),
                            strokeWidth: 2.2,
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 50,
                    top: 488,
                    width: 260,
                    height: 16,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (_, __) {
                        return CustomPaint(
                          painter: _ProgressBarPainter(
                            progress: _progressController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double strokeWidth;

  const _OutlinedText({
    required this.text,
    required this.style,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = style.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = _black,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, textAlign: TextAlign.center, style: outlineStyle),
        Text(text, textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;

  const _ProgressBarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outerRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );

    canvas.drawRRect(
      outerRRect,
      Paint()
        ..color = _progressBackground
        ..style = PaintingStyle.fill,
    );

    final double progressWidth = size.width * progress;

    if (progressWidth > 0) {
      final RRect progressRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, progressWidth, size.height),
        const Radius.circular(9),
      );

      canvas.drawRRect(
        progressRRect,
        Paint()
          ..color = _progressColor
          ..style = PaintingStyle.fill,
      );
    }

    final Paint innerShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final Path innerShadowPath = Path()
      ..moveTo(5, size.height - 2)
      ..lineTo(size.width - 5, size.height - 2);

    canvas.save();
    canvas.clipRRect(outerRRect);
    canvas.drawPath(innerShadowPath, innerShadowPaint);
    canvas.restore();

    canvas.drawRRect(
      outerRRect,
      Paint()
        ..color = _black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
