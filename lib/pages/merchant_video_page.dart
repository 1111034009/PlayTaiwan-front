import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'merchant_home_page.dart';

const Color _backgroundColor = Color(0xFFC4ADA0);
const Color _cardColor = Color(0xFFFCF9EA);
const Color _darkRed = Color(0xFF7E1616);
const Color _textColor = Color(0xFF17110F);
const Color _lightText = Color(0xFFFCF9EA);
const Color _buttonText = Color(0xFFEBE1C7);
const Color _buttonInner = Color(0xFF724E4E);
const Color _buttonOuter = Color(0xFF301717);
const Color _black = Colors.black;

TextStyle kaisei({
  double size = 16,
  FontWeight weight = FontWeight.w400,
  Color color = _textColor,
}) {
  return GoogleFonts.kaiseiHarunoUmi(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

class MerchantVideoPage extends StatelessWidget {
  const MerchantVideoPage({super.key});

  static const double designWidth = 360;
  static const double designHeight = 820;

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MerchantHomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: _backgroundColor),
                    ),
                    Positioned(
                      top: 10,
                      left: 23,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _goHome(context),
                        child: Text(
                          '＜＜ 返回',
                          style:
                              kaisei(
                                size: 14,
                                weight: FontWeight.w600,
                                color: _lightText,
                              ).copyWith(
                                shadows: const [
                                  Shadow(
                                    color: Color(0x55000000),
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 45,
                      left: 23,
                      right: 23,
                      child: _ContentCard(),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      top: 740,
                      child: Row(
                        children: [
                          Expanded(
                            child: _ShareButton(
                              text: '一鍵分享ig',
                              onTap: _shareInstagram,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _ShareButton(
                              text: '一鍵分享脆',
                              onTap: _shareThreads,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _shareInstagram() {}

  static void _shareThreads() {}
}

class _ContentCard extends StatelessWidget {
  const _ContentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: 'img/reel.png',
            title: 'Reels 影音',
            actions: ['img/video_download.png', 'img/video_edit.png'],
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(width: 230, height: 318, color: Colors.black),
          ),
          const SizedBox(height: 12),
          const _SectionHeader(
            icon: 'img/reel_content.png',
            title: 'Reels 推薦配文',
            actions: ['img/copy.png'],
          ),
          const SizedBox(height: 5),
          const _ContentTextBox(
            text:
                '''下班後的微醺，是你應得的獎賞。\n🍻 隱身在城市巷弄的日式復古角落，碳火香氣與冰涼生啤的完美交響曲。\n✨ 本週末限定：點指定串燒拼盤，即贈特製小菜乙份！位置有限，快@那個總是說要約的酒肉朋友，今晚就出發！👇''',
          ),
          const SizedBox(height: 15),
          const _SectionHeader(
            icon: 'img/tag.png',
            title: 'Reels 推薦標籤',
            actions: ['img/copy.png'],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Tag(text: '#居酒屋推薦'),
              _Tag(text: '#老井美食'),
              _Tag(text: '#朋友聚會'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final List<String> actions;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(icon, width: 22, height: 22, fit: BoxFit.contain),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kaisei(size: 20, weight: FontWeight.w900, color: _textColor),
          ),
        ),
        for (final action in actions) ...[
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Image.asset(
              action,
              width: 21,
              height: 21,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ],
    );
  }
}

class _ContentTextBox extends StatelessWidget {
  final String text;

  const _ContentTextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: kaisei(
          size: 13,
          weight: FontWeight.w700,
          color: _textColor,
        ).copyWith(height: 1.42),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _darkRed,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: _buttonOuter, offset: Offset(0, 2), blurRadius: 0),
        ],
      ),
      child: Text(
        text,
        style: kaisei(
          size: 12,
          weight: FontWeight.w700,
          color: _lightText,
        ).copyWith(height: 1),
      ),
    );
  }
}

class _ShareButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _ShareButton({required this.text, required this.onTap});

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 44,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const RadialGradient(
            center: Alignment.center,
            radius: 1.25,
            colors: [_buttonInner, _buttonOuter],
          ),
          border: Border.all(color: _buttonText, width: 2),
          boxShadow: const [
            BoxShadow(color: _black, offset: Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: kaisei(
              size: 16,
              weight: FontWeight.w700,
              color: _buttonText,
            ).copyWith(height: 1),
          ),
        ),
      ),
    );
  }
}
