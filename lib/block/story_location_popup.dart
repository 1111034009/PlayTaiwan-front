import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_text_styles.dart';
import '../core/app_colors.dart';

const Color _popupBackground = AppColors.paper;
const Color _popupText = AppColors.textPrimary;
const Color _popupRed = AppColors.primaryAccent;

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

class StoryLocationPopup extends StatelessWidget {
  final String title;
  final String description;

  final VoidCallback onClose;
  final VoidCallback onReviewStory;
  final VoidCallback onAround;
  final VoidCallback onMission;
  final VoidCallback onNavigate;

  const StoryLocationPopup({
    super.key,
    required this.title,
    required this.description,
    required this.onClose,
    required this.onReviewStory,
    required this.onAround,
    required this.onMission,
    required this.onNavigate,
  });

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _popupText,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: AppTextStyles.normalizeFontSize(size),
      fontWeight: weight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _popupBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 0, 55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 60),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kaisei(
                              size: AppTextStyles.titleSize,
                              weight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ReviewButton(onTap: onReviewStory, kaisei: kaisei),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 0,
                    child: _CloseButton(onTap: onClose),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: kaisei(
                  size: AppTextStyles.bodySmallSize,
                  weight: FontWeight.w800,
                ).copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _GradientButton(
                      text: '周邊好去',
                      onTap: onAround,
                      kaisei: kaisei,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _GradientButton(
                      text: '查看任務',
                      onTap: onMission,
                      kaisei: kaisei,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _GradientButton(
                      text: '開始導航',
                      onTap: onNavigate,
                      kaisei: kaisei,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Image.asset(
            'img/NO.png',
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _ReviewButton extends StatefulWidget {
  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _ReviewButton({required this.onTap, required this.kaisei});

  @override
  State<_ReviewButton> createState() => _ReviewButtonState();
}

class _ReviewButtonState extends State<_ReviewButton> {
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
          style: widget.kaisei(
            size: AppTextStyles.bodySmallSize,
            weight: FontWeight.w900,
            color: _popupRed,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _GradientButton({
    required this.text,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.95 : 1.0;

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
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
            style: widget.kaisei(
              size: AppTextStyles.bodySmallSize,
              weight: FontWeight.w700,
              color: const Color(0xFFEBE1C7),
            ),
          ),
        ),
      ),
    );
  }
}
