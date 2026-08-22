import 'package:flutter/material.dart';
import 'merchant_home_page.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const Color _backgroundColor = Color(0xFFC4ADA0);
const Color _cardColor = AppColors.merchantPaper;
const Color _darkRed = AppColors.primaryAccent;
const Color _textColor = Color(0xFF17110F);
const Color _lightText = AppColors.merchantPaper;
const Color _buttonText = AppColors.paper;
const Color _buttonInner = Color(0xFF724E4E);
const Color _buttonOuter = AppColors.textPrimary;
const Color _black = Colors.black;
class MerchantVideoPage extends StatelessWidget {
  const MerchantVideoPage({super.key});

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 42,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _goHome(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          child: Text(
                            '<< 返回',
                            style:
                                AppTextStyles.bodySmallBold.copyWith(color: _lightText).copyWith(
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
                    ),
                    const SizedBox(height: 10),
                    const _ContentCard(),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ShareButton(
                            text: '一鍵分享ig',
                            onTap: _shareInstagram,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ShareButton(
                            text: '一鍵分享脆',
                            onTap: _shareThreads,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SectionHeader(
            icon: 'img/reel.png',
            title: 'Reels 影音',
            actions: ['img/video_download.png', 'img/video_edit.png'],
          ),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: AspectRatio(
                aspectRatio: 230 / 318,
                child: Container(width: double.infinity, color: Colors.black),
              ),
            ),
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
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: AppTextStyles.sectionTitle.copyWith(color: _textColor),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Image.asset(
                      actions[i],
                      width: 21,
                      height: 21,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ],
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
        softWrap: true,
        style: AppTextStyles.captionBold.copyWith(color: _textColor).copyWith(height: 1.42),
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
        softWrap: false,
        style: AppTextStyles.label.copyWith(color: _lightText).copyWith(height: 1),
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
        constraints: const BoxConstraints(minHeight: 44),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text,
                maxLines: 1,
                style: AppTextStyles.button.copyWith(color: _buttonText).copyWith(height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
