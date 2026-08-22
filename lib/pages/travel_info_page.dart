import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import '../block/navigationbar.dart';
import 'choose_script_page.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;
const Color _optionColor = AppColors.storyBackground;

const Color _redrawBorder = AppColors.primaryDark;
const Color _redrawCenter = AppColors.primaryLight;
const Color _redrawOuter = AppColors.primary;

class TravelInfoPage extends StatefulWidget {
  const TravelInfoPage({super.key});

  @override
  State<TravelInfoPage> createState() => _TravelInfoPageState();
}

class _TravelInfoPageState extends State<TravelInfoPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  int currentIndex = 1;

  final TextEditingController peopleController = TextEditingController();

  final Set<String> selectedPreferences = {};
  final Set<String> selectedTransports = {};

  bool isGenerating = false;
  int generatingStep = 0;
  String generatingText = '正在整理旅程線索';

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    peopleController.dispose();
    super.dispose();
  }
  void togglePreference(String value) {
    setState(() {
      if (selectedPreferences.contains(value)) {
        selectedPreferences.remove(value);
      } else {
        selectedPreferences.add(value);
      }
    });
  }

  void toggleTransport(String value) {
    setState(() {
      if (selectedTransports.contains(value)) {
        selectedTransports.remove(value);
      } else {
        selectedTransports.add(value);
      }
    });
  }

  Future<void> generateScript() async {
    final String people = peopleController.text.trim();

    if (people.isEmpty) {
      _showMessage('請先輸入旅程人數');
      return;
    }

    final int? peopleCount = int.tryParse(people);

    if (peopleCount == null || peopleCount <= 0) {
      _showMessage('旅程人數請輸入正確數字');
      return;
    }

    if (selectedPreferences.isEmpty) {
      _showMessage('請至少選擇一項偏好');
      return;
    }

    if (selectedTransports.isEmpty) {
      _showMessage('請至少選擇一種交通方式');
      return;
    }

    if (isGenerating) {
      return;
    }

    setState(() {
      isGenerating = true;
      generatingStep = 0;
      generatingText = '正在整理旅程線索';
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() {
      generatingStep = 1;
      generatingText = '正在分析隊伍偏好';
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() {
      generatingStep = 2;
      generatingText = '正在編排解謎劇本';
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    setState(() {
      generatingStep = 3;
      generatingText = '劇本即將完成';
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    setState(() {
      isGenerating = false;
    });

    _showScriptCompleteDialog();
  }

  void _showScriptCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.82),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: AppColors.warmPaper,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _redrawBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _redrawCenter,
                    border: Border.all(color: _redrawBorder, width: 3),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '劇本生成完成',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.pageTitle.copyWith(color: _darkText),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChooseScriptPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redrawCenter,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: Text(
                      '前往選擇劇本',
                      style: AppTextStyles.bodyEmphasisBold.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: _optionColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _pageColor,
          extendBody: true,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: designWidth,
                      height: designHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: Container(color: _pageColor)),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 45,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'img/user_icon_line.png',
                                    width: 27,
                                    height: 27,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 8),
                                  _OutlinedTitle(text: '組隊集結'),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 85,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE9DDC6,
                                  ).withOpacity(0.88),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF8A7163,
                                    ).withOpacity(0.30),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '輸入資訊，讓這場解謎旅程正式展開',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyEmphasisBold.copyWith(color: _darkBrown),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 13,
                            top: 130,
                            width: 334,
                            height: 475,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Image.asset(
                                'img/background_papper.png',
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 39,
                            top: 157,
                            width: 282,
                            child: _FormContent(
                              peopleController: peopleController,
                              selectedPreferences: selectedPreferences,
                              selectedTransports: selectedTransports,
                              onPreferenceTap: togglePreference,
                              onTransportTap: toggleTransport,
                              onGenerate: generateScript,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
        ),
        if (isGenerating)
          Positioned.fill(
            child: _ScriptGeneratingOverlay(
              message: generatingText,
              step: generatingStep,
),
          ),
      ],
    );
  }
}

class _OutlinedTitle extends StatelessWidget {
  final String text;
const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = AppTextStyles.displayLarge.copyWith(color: _darkBrown)
        .copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..color = _darkBrown,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: outlineStyle),
        Text(
          text,
          style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _FormContent extends StatelessWidget {
  final TextEditingController peopleController;
  final Set<String> selectedPreferences;
  final Set<String> selectedTransports;
  final ValueChanged<String> onPreferenceTap;
  final ValueChanged<String> onTransportTap;
  final VoidCallback onGenerate;

  const _FormContent({
    required this.peopleController,
    required this.selectedPreferences,
    required this.selectedTransports,
    required this.onPreferenceTap,
    required this.onTransportTap,
    required this.onGenerate,
  });

  Widget choice({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: _ChoiceButton(
        text: text,
        selected: selected,
        onTap: onTap,
      ),
    );
  }

  Widget transportChoice({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 88.666,
      child: _ChoiceButton(
        text: text,
        selected: selected,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '旅程人數',
          style: AppTextStyles.titleMediumBold.copyWith(color: _darkText),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 42,
          child: TextField(
            controller: peopleController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.left,
            style: AppTextStyles.bodyEmphasisBold.copyWith(color: _darkText),
            cursorColor: _optionColor,
            decoration: InputDecoration(
              hintText: '請輸入數字',
              hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText),
              contentPadding: const EdgeInsets.only(
                left: 5,
                right: 5,
                top: 5,
                bottom: 10,
              ),
              isDense: true,
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _optionColor, width: 1),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _optionColor, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '偏好(可複選)',
          style: AppTextStyles.sectionTitle.copyWith(color: _darkText),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            choice(
              text: '家庭出遊',
              selected: selectedPreferences.contains('家庭出遊'),
              onTap: () => onPreferenceTap('家庭出遊'),
            ),
            const SizedBox(width: 8),
            choice(
              text: '好友結伴',
              selected: selectedPreferences.contains('好友結伴'),
              onTap: () => onPreferenceTap('好友結伴'),
            ),
            const SizedBox(width: 8),
            choice(
              text: '文學建築',
              selected: selectedPreferences.contains('文學建築'),
              onTap: () => onPreferenceTap('文學建築'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            choice(
              text: '尋訪味蕾',
              selected: selectedPreferences.contains('尋訪味蕾'),
              onTap: () => onPreferenceTap('尋訪味蕾'),
            ),
            const SizedBox(width: 8),
            choice(
              text: '探險運動',
              selected: selectedPreferences.contains('探險運動'),
              onTap: () => onPreferenceTap('探險運動'),
            ),
            const SizedBox(width: 8),
            choice(
              text: '解謎深入',
              selected: selectedPreferences.contains('解謎深入'),
              onTap: () => onPreferenceTap('解謎深入'),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          '交通方式(可複選)',
          style: AppTextStyles.sectionTitle.copyWith(color: _darkText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            transportChoice(
              text: '公車',
              selected: selectedTransports.contains('公車'),
              onTap: () => onTransportTap('公車'),
            ),
            transportChoice(
              text: '捷運',
              selected: selectedTransports.contains('捷運'),
              onTap: () => onTransportTap('捷運'),
            ),
            transportChoice(
              text: '腳踏車',
              selected: selectedTransports.contains('腳踏車'),
              onTap: () => onTransportTap('腳踏車'),
            ),
            transportChoice(
              text: '步行',
              selected: selectedTransports.contains('步行'),
              onTap: () => onTransportTap('步行'),
            ),
            transportChoice(
              text: '其他',
              selected: selectedTransports.contains('其他'),
              onTap: () => onTransportTap('其他'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Align(
          alignment: Alignment.center,
          child: _GenerateButton(text: '生成專屬劇本', onPressed: onGenerate),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.97
        : hovering
        ? 1.015
        : 1.0;

    return MouseRegion(
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
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected
                  ? _optionColor
                  : AppColors.warmPaper.withOpacity(0.65),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _optionColor, width: 1.4),
              boxShadow: widget.selected
                  ? const [
                      BoxShadow(
                        color: Color(0x30000000),
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold.copyWith(color: widget.selected ? Colors.white : _optionColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const _GenerateButton({required this.text, required this.onPressed});

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.97
        : hovering
        ? 1.015
        : 1.0;

    return MouseRegion(
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
        onTap: widget.onPressed,
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
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Container(
            width: 180,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _redrawBorder, width: 2),
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_redrawCenter, _redrawCenter, _redrawOuter],
                stops: [0.0, 0.45, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyCompactBold.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScriptGeneratingOverlay extends StatefulWidget {
  final String message;
  final int step;
  const _ScriptGeneratingOverlay({
    required this.message,
    required this.step,
});

  @override
  State<_ScriptGeneratingOverlay> createState() =>
      _ScriptGeneratingOverlayState();
}

class _ScriptGeneratingOverlayState extends State<_ScriptGeneratingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
      color: Colors.black.withOpacity(0.88),
      child: SizedBox.expand(
        child: Center(
          child: Container(
            width: 282,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: BoxDecoration(
              color: AppColors.warmPaper,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _redrawBorder, width: 2),
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
                      border: Border.all(color: _redrawBorder, width: 3),
                    ),
                    child: Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _redrawCenter,
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
                  style: AppTextStyles.titleLarge.copyWith(color: _darkText),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    widget.message,
                    key: ValueKey(widget.message),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmallBold.copyWith(color: _darkBrown),
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 7,
                    width: double.infinity,
                    color: const Color(0xFFD0C0A8),
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      alignment: Alignment.centerLeft,
                      widthFactor: (widget.step + 1) / 4,
                      child: Container(color: _redrawCenter),
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
                  style: AppTextStyles.microSmall.copyWith(color: const Color(0xFF77685F)),
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

        double opacity;

        if (value < 0.5) {
          opacity = 0.3 + (value * 2 * 0.7);
        } else {
          opacity = 1.0 - ((value - 0.5) * 2 * 0.7);
        }

        return Opacity(
          opacity: opacity.clamp(0.25, 1.0),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _redrawCenter,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
