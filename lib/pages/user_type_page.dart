import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class UserTypePage extends StatelessWidget {
  const UserTypePage({super.key});

  static const Color pageColor = AppColors.background;
  static const Color darkText = AppColors.textPrimary;
  static const Color red = AppColors.primaryAccent;
  void goTraveler(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void goMerchant(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/merchant-home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('選擇使用模式', style: AppTextStyles.displayLargeWide.copyWith(color: darkText)),
              const SizedBox(height: 36),

              _ModeButton(
                text: '旅客使用',
                color: red,
                onTap: () => goTraveler(context),
              ),

              const SizedBox(height: 20),

              _ModeButton(
                text: '商家使用',
                color: red,
                onTap: () => goMerchant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing ? 0.96 : 1.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.primaryDark, width: 2),
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.2),
              radius: 1.15,
              colors: [
                AppColors.primaryLight,
                AppColors.primaryLight,
                AppColors.primary,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.text,
            style: AppTextStyles.subtitle.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
