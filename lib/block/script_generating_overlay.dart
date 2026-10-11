import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class ScriptGeneratingOverlay extends StatefulWidget {
  final String message;
  final double progress;

  const ScriptGeneratingOverlay({
    super.key,
    required this.message,
    required this.progress,
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
                const SizedBox(height: 8),
                Text(
                  '請稍候，線索正在重新排列……',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.microSmall.copyWith(
                    color: const Color(0xFF77685F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
