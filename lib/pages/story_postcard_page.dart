import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../block/navigationbar.dart';
import 'story_end_page.dart';
import '../core/app_text_styles.dart';
import '../core/app_colors.dart';

const Color _backgroundColor = AppColors.storyBackground;
const Color _lightText = AppColors.paper;
const Color _white80 = Color(0xCCFFFFFF);

const Color _secondaryBorder = AppColors.paper;
const Color _secondaryCenter = Color(0xFF724E4E);
const Color _secondaryOuter = AppColors.pastBackground;

const Color _primaryBorder = AppColors.primaryDark;
const Color _primaryCenter = AppColors.primaryLight;
const Color _primaryOuter = AppColors.primary;

class StoryPostcardPage extends StatefulWidget {
  final VoidCallback? onNext;

  const StoryPostcardPage({super.key, this.onNext});

  @override
  State<StoryPostcardPage> createState() => _StoryPostcardPageState();
}

class _StoryPostcardPageState extends State<StoryPostcardPage> {
  static const double designWidth = 430;
  static const double designHeight = 760;

  int currentIndex = 1;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _backgroundColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ============================================================
  // 字體
  // ============================================================
  // ============================================================
  // 下一站功能
  // ============================================================

  void goNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StoryEndPage()),
    );
  }
  // ============================================================
  // 回首頁功能
  // ============================================================

  void goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ============================================================
  // 訊息提示功能
  // ============================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white).copyWith(height: 1.2),
          ),
          backgroundColor: _backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ============================================================
  // 畫面
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      extendBody: true,

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
                // ==================================================
                // 背景
                // ==================================================
                const Positioned.fill(
                  child: ColoredBox(color: _backgroundColor),
                ),

                // ==================================================
                // 主標題
                // ==================================================
                Positioned(
                  left: 0,
                  right: 0,
                  top: 90,
                  child: Center(
                    child: _OutlinedTitle(text: '謎題解開'),
                  ),
                ),

                // ==================================================
                // 副標題
                // ==================================================
                Positioned(
                  left: 0,
                  right: 0,
                  top: 132,
                  child: Center(
                    child: Text(
                      '獲得專屬記憶明信片',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sectionTitle.copyWith(color: _white80).copyWith(height: 1.2, letterSpacing: 0.35),
                    ),
                  ),
                ),

                // ==================================================
                // 明信片
                // ==================================================
                Positioned(
                  left: 25,
                  top: 190,
                  width: 380,
                  height: 253,
                  child: const _PostcardDisplay(),
                ),

                // ==================================================
                // 實體列印
                // ==================================================
                Positioned(
                  left: 22,
                  top: 478,
                  width: 184,
                  height: 52,
                  child: _SecondaryButton(
                    text: '實體列印',
                    onTap: () {
                      showMessage('已準備列印功能');
                    },
                  ),
                ),

                // ==================================================
                // 分享
                // ==================================================
                Positioned(
                  left: 224,
                  top: 478,
                  width: 184,
                  height: 52,
                  child: _SecondaryButton(
                    text: '分享',
                    onTap: () {
                      showMessage('已準備分享功能');
                    },
                  ),
                ),

                // ==================================================
                // 前往下一站
                // ==================================================
                Positioned(
                  left: 22,
                  right: 22,
                  top: 552,
                  height: 53,
                  child: _PrimaryButton(
                    text: '前往下一站',
                    onTap: goNext,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ============================================================
      // 底部導覽列
      // ============================================================
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ============================================================
// 標題功能
// ============================================================

class _OutlinedTitle extends StatelessWidget {
  final String text;
const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 黑色外框
        Text(
          text,
          style: AppTextStyles.heroDisplay.copyWith(color: _lightText).copyWith(
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2
              ..color = Colors.black,
          ),
        ),

        // 白色文字
        Text(
          text,
          style: AppTextStyles.heroDisplay.copyWith(color: Colors.white).copyWith(height: 1.0),
        ),
      ],
    );
  }
}

// ============================================================
// 明信片顯示功能
// ============================================================

class _PostcardDisplay extends StatelessWidget {
  const _PostcardDisplay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x70000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'img/example_postcard.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// ============================================================
// 次要按鈕功能
// ============================================================

class _SecondaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _SecondaryButton({
    required this.text,
    required this.onTap,
});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.07
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
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
            alignment: Alignment.center,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),

              border: Border.all(color: _secondaryBorder, width: 2),

              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_secondaryCenter, _secondaryCenter, _secondaryOuter],
                stops: [0.0, 0.45, 1.0],
              ),

              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),

            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(color: _lightText)
                  .copyWith(height: 1.1, letterSpacing: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 主要按鈕功能
// ============================================================

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.text,
    required this.onTap,
});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.06
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
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
            alignment: Alignment.center,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),

              border: Border.all(color: _primaryBorder, width: 2),

              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_primaryCenter, _primaryCenter, _primaryOuter],
                stops: [0.0, 0.45, 1.0],
              ),

              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),

            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMediumBold.copyWith(color: _lightText)
                  .copyWith(height: 1.1, letterSpacing: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
