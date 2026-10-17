import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class ScriptGeneratingOverlay extends StatefulWidget {
  final String message;
  final double progress;
  final String? detail;
  final int? stage;

  const ScriptGeneratingOverlay({
    super.key,
    required this.message,
    required this.progress,
    this.detail,
    this.stage,
  });

  @override
  State<ScriptGeneratingOverlay> createState() =>
      _ScriptGeneratingOverlayState();
}

class _ScriptGeneratingOverlayState extends State<ScriptGeneratingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: SizedBox.expand(
        child: Center(
          child: Container(
            width: 282,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: BoxDecoration(
              color: AppColors.warmPaper,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.primaryDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xCC000000),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.stage != null)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _SweetPotatoPainter(
                            t: _controller.value,
                            stage: widget.stage!,
                          ),
                        );
                      },
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _controller.value * 6.28318,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryDark,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryLight,
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                Text(
                  '劇本撰寫中',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    widget.message,
                    key: ValueKey(widget.message),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: AppColors.darkBrown,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 10,
                    width: double.infinity,
                    color: const Color(0xFFD0C0A8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: widget.progress.clamp(0.0, 1.0),
                      ),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primary,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (widget.detail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.detail!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LoadingDot(animation: _controller, delay: 0.0),
                    const SizedBox(width: 7),
                    _LoadingDot(animation: _controller, delay: 0.2),
                    const SizedBox(width: 7),
                    _LoadingDot(animation: _controller, delay: 0.4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SweetPotatoPainter extends CustomPainter {
  final double t;
  final int stage;

  const _SweetPotatoPainter({required this.t, required this.stage});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 96;

    canvas.scale(s, s);

    final double bob = math.sin(t * math.pi * 2) * 2;

    final Paint fill = Paint()..style = PaintingStyle.fill;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    fill.color = const Color(0x22000000);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(46, 88), width: 52, height: 7),
      fill,
    );

    canvas.translate(0, bob);

    if (stage == 0) {
      _paintMagnifier(canvas, fill, line);
    } else {
      _paintWriting(canvas, fill, line);
    }

    canvas.save();
    canvas.translate(46, 54);
    canvas.rotate(-0.3);

    fill.color = const Color(0xFF9A4B6E);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 64, height: 44),
      fill,
    );

    fill.color = const Color(0x33FFFFFF);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-8, -11), width: 30, height: 9),
      fill,
    );

    line.color = const Color(0xFF6E2F4C);
    line.strokeWidth = 1.6;
    canvas.drawLine(const Offset(-22, 6), const Offset(-14, 8), line);
    canvas.drawLine(const Offset(8, 13), const Offset(18, 11), line);
    canvas.drawLine(const Offset(30, 2), const Offset(38, 4), line);
    canvas.drawLine(const Offset(-32, 0), const Offset(-39, -2), line);

    canvas.restore();

    fill.color = const Color(0xFF6FA35A);
    canvas.save();
    canvas.translate(36, 32);
    canvas.rotate(-0.7);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, -4), width: 12, height: 6),
      fill,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(36, 32);
    canvas.rotate(0.5);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, -5), width: 12, height: 6),
      fill,
    );
    canvas.restore();

    final double phase = t % 1.0;
    final double blink = (phase > 0.45 && phase < 0.5) ? 0.15 : 1.0;

    fill.color = const Color(0xFF301717);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(38, 51),
        width: 4.4,
        height: 5.6 * blink,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(53, 48),
        width: 4.4,
        height: 5.6 * blink,
      ),
      fill,
    );

    fill.color = const Color(0x66FF8FA3);
    canvas.drawCircle(const Offset(33, 57), 3.4, fill);
    canvas.drawCircle(const Offset(58, 54), 3.4, fill);

    line.color = const Color(0xFF301717);
    line.strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(46, 56), width: 10, height: 7),
      0.2 * math.pi,
      0.6 * math.pi,
      false,
      line,
    );
  }

  void _paintMagnifier(Canvas canvas, Paint fill, Paint line) {
    final double sway = math.sin(t * math.pi * 2) * 4;

    line.color = const Color(0xFF8A4A63);
    line.strokeWidth = 4;
    canvas.drawLine(const Offset(60, 48), Offset(63 + sway, 35), line);

    final Offset center = Offset(74 + sway, 24);

    line.color = const Color(0xFF6D4C41);
    line.strokeWidth = 3.4;
    canvas.drawLine(
      Offset(center.dx - 6.4, center.dy + 6.4),
      Offset(63 + sway, 35),
      line,
    );

    fill.color = const Color(0x55BBE3F5);
    canvas.drawCircle(center, 9, fill);

    line.color = const Color(0xFF6D4C41);
    line.strokeWidth = 3;
    canvas.drawCircle(center, 9, line);

    line.color = const Color(0x88FFFFFF);
    line.strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 5.5),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      line,
    );
  }

  void _paintWriting(Canvas canvas, Paint fill, Paint line) {
    final RRect paper = RRect.fromRectAndRadius(
      const Rect.fromLTWH(62, 26, 24, 30),
      const Radius.circular(2),
    );

    fill.color = const Color(0xFFF8F4EC);
    canvas.drawRRect(paper, fill);

    line.color = const Color(0xFF8D7B6E);
    line.strokeWidth = 1;
    canvas.drawRRect(paper, line);

    final double p = (t * 4) % 4;
    final int current = p.floor().clamp(0, 3);
    final double frac = p - current;

    line.color = const Color(0xFF8B837B);
    line.strokeWidth = 1.4;

    for (int i = 0; i < 4; i++) {
      final double length = i < current ? 16 : (i == current ? 16 * frac : 0);

      if (length <= 0) continue;

      canvas.drawLine(
        Offset(66, 33 + i * 6.0),
        Offset(66 + length, 33 + i * 6.0),
        line,
      );
    }

    final Offset tip = Offset(66 + 16 * frac, 33 + current * 6.0);
    final Offset top = Offset(tip.dx + 7, tip.dy - 10);

    line.color = const Color(0xFF8A4A63);
    line.strokeWidth = 4;
    canvas.drawLine(const Offset(58, 50), top, line);

    line.color = const Color(0xFF8D1F12);
    line.strokeWidth = 2.6;
    canvas.drawLine(tip, top, line);

    fill.color = const Color(0xFF301717);
    canvas.drawCircle(tip, 1.2, fill);
  }

  @override
  bool shouldRepaint(covariant _SweetPotatoPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.stage != stage;
  }
}

class _LoadingDot extends StatelessWidget {
  final Animation<double> animation;
  final double delay;

  const _LoadingDot({required this.animation, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double value = (animation.value + delay) % 1.0;

        final double opacity = value < 0.5
            ? 0.3 + (value * 2 * 0.7)
            : 1.0 - ((value - 0.5) * 2 * 0.7);

        return Opacity(
          opacity: opacity.clamp(0.25, 1.0),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
