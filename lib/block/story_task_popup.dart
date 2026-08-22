import 'package:flutter/material.dart';
import '../core/app_text_styles.dart';
import '../core/app_colors.dart';
const Color _taskBackground = Color(0xFFE2D8BD);
const Color _taskText = AppColors.textPrimary;
const Color _taskRed = AppColors.primaryAccent;

const Color _dialogBackground = Color(0xFFF7F2E8);
const Color _dialogBorder = Color(0xFFD8CFBC);

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

class StoryTaskPopup extends StatelessWidget {
  final String title;

  final VoidCallback onClose;
  final VoidCallback onReviewStory;
  final VoidCallback onBack;
  final VoidCallback onStartTask;

  const StoryTaskPopup({
    super.key,
    required this.title,
    required this.onClose,
    required this.onReviewStory,
    required this.onBack,
    required this.onStartTask,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _taskBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 32,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 52,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleLarge.copyWith(color: _taskText),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _ReviewStoryButton(
                          onTap: onReviewStory,
),
                      ],
                    ),
                  ),

                  Positioned(
                    right: 0,
                    top: 0,
                    child: _CloseButton(onTap: onClose),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Image.asset(
                    'img/npc_head.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _TaskDialogBubble(
                    child: Text(
                      '進入此地，你將看見一方高懸的古老匾額。\n'
                      '它們曾由歷代皇帝御賜，跨越不同的歲月，'
                      '至今仍留在這座古老府城之中。\n'
                      '若想找回最初的那段記憶……\n'
                      '就從最早留下的一方開始尋找吧。',
                      textAlign: TextAlign.left,
                      style: AppTextStyles.bodySmallBold.copyWith(color: _taskText).copyWith(height: 1.45),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Center(
              child: _GradientButton(
                text: '解開彌封',
                onTap: onStartTask,
),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _TaskDialogBubble extends StatelessWidget {
  final Widget child;

  const _TaskDialogBubble({required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TaskDialogPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      ),
    );
  }
}

class _TaskDialogPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final RRect rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(rect.shift(const Offset(0, 2)), shadowPaint);

    final Paint fillPaint = Paint()
      ..color = _dialogBackground
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, fillPaint);

    final Paint borderPaint = Paint()
      ..color = _dialogBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TaskDialogPainter oldDelegate) {
    return false;
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.90 : 1.0;

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
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Image.asset(
              'img/NO.png',
              width: 19,
              height: 19,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStoryButton extends StatefulWidget {
  final VoidCallback onTap;
const _ReviewStoryButton({required this.onTap});

  @override
  State<_ReviewStoryButton> createState() => _ReviewStoryButtonState();
}

class _ReviewStoryButtonState extends State<_ReviewStoryButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1.0;

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
        child: Text(
          '回顧劇情 >>',
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(color: _taskRed),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _GradientButton({
    required this.text,
    required this.onTap,
});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1.0;

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
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutBack,
        child: Container(
          width: 282,
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _buttonBorder, width: 2),
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.2),
              radius: 1.15,
              colors: [_buttonCenter, _buttonCenter, _buttonOuter],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: AppTextStyles.button.copyWith(color: AppColors.paper),
          ),
        ),
      ),
    );
  }
}
