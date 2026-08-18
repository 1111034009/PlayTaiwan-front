import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserTypePage extends StatelessWidget {
  const UserTypePage({super.key});

  static const Color pageColor = Color(0xFFB9ACA2);
  static const Color darkText = Color(0xFF301717);
  static const Color red = Color(0xFF8D1F12);

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = darkText,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

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
              Text('選擇使用模式', style: kaisei(size: 26, weight: FontWeight.w700)),
              const SizedBox(height: 36),

              _ModeButton(
                text: '旅客使用',
                color: red,
                kaisei: kaisei,
                onTap: () => goTraveler(context),
              ),

              const SizedBox(height: 20),

              _ModeButton(
                text: '商家使用',
                color: red,
                kaisei: kaisei,
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
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;
  final VoidCallback onTap;

  const _ModeButton({
    required this.text,
    required this.color,
    required this.kaisei,
    required this.onTap,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing
        ? 0.96
        : hovering
        ? 1.06
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
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
              border: Border.all(color: const Color(0xFF4A1106), width: 2),
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [
                  Color(0xFF9B2A15),
                  Color(0xFF9B2A15),
                  Color(0xFF7D1907),
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
              style: widget.kaisei(
                size: 17,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
