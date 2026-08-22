import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import '../block/navigationbar.dart';
import 'story_postcard_page.dart';

const Color _background = AppColors.questionBackground;
const Color _textColor = AppColors.textPrimary;
const Color _optionTextColor = Color(0xFF000000);
const Color _selectedTextColor = AppColors.paper;
const Color _selectedBackground = AppColors.dangerDark;
const Color _answerBorder = Color(0xFF000000);
const Color _hintTextColor = Color(0x99000000);
const Color _red = AppColors.primaryAccent;

const Color _buttonColor = AppColors.primary;
const Color _buttonBorder = AppColors.primaryDark;

class StoryQuestionPage extends StatefulWidget {
  const StoryQuestionPage({super.key});

  @override
  State<StoryQuestionPage> createState() => _StoryQuestionPageState();
}

class _StoryQuestionPageState extends State<StoryQuestionPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  int? selectedAnswer;
  int currentIndex = 1;

  final String question = '御匾歷經百年仍高懸於此。其中最早的一方，出自哪位皇帝之手？';

  final List<String> answers = ['康熙', '雍正', '乾隆', '光緒'];

  static const int correctAnswer = 0;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  void _goBack() {
    Navigator.pop(context);
  }

  void _showTip() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '線索',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return const _ClueScrollDialog(
              clueText:
                  '八方御匾，皆有來歷。\n'
                  '康、雍、乾這些名字，\n'
                  '哪一個最早出現在歷史之中？',
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
    );
  }

  void _showWrongAnswerClue() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '錯題線索',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return const _ClueScrollDialog(clueText: '八方御匾中，有一方屬於清朝最早的一位皇帝');
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
    );
  }

  void _submitAnswer() {
    if (selectedAnswer == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '請先選擇一個答案',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyEmphasisBold.copyWith(color: Colors.white).copyWith(height: 1.1, letterSpacing: 0.2),
            ),
            backgroundColor: AppColors.storyBackground,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

      return;
    }

    final bool isCorrect = selectedAnswer == correctAnswer;

    if (!isCorrect) {
      _showWrongAnswerClue();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StoryPostcardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        extendBody: true,
        body: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: _background),
                    ),
                    Positioned(
                      left: -20,
                      top: 38,
                      width: 400,
                      height: 564,
                      child: Image.asset(
                        'img/long_papper.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 79,
                      child: _BackButton(onTap: _goBack),
                    ),
                    Positioned(
                      right: 10,
                      top: 77,
                      child: _TipButton(onTap: _showTip),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 102,
                      bottom: 62,
                      child: Center(
                        child: SizedBox(
                          width: 292,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _QuestionPaper(
                                  question: question,
),
                                const SizedBox(height: 22),
                                ...List.generate(answers.length, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 18),
                                    child: SizedBox(
                                      width: 292,
                                      child: _AnswerOption(
                                        text:
                                            '${String.fromCharCode(65 + index)}.${answers[index]}',
                                        selected: selectedAnswer == index,
                                        onTap: () {
                                          setState(() {
                                            selectedAnswer = index;
                                          });
                                        },
),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                Center(
                                  child: _SubmitButton(
                                    text: '確認送出',
                                    onTap: _submitAnswer,
),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.03
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Text(
            '<< 返回',
            style: AppTextStyles.subtitle.copyWith(color: _red)
                .copyWith(height: 1.0, letterSpacing: 0.08),
          ),
        ),
      ),
    );
  }
}

class _TipButton extends StatefulWidget {
  final VoidCallback onTap;

  const _TipButton({required this.onTap});

  @override
  State<_TipButton> createState() => _TipButtonState();
}

class _TipButtonState extends State<_TipButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.90
        : hovering
        ? 1.06
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
          child: Image.asset(
            'img/tip.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _QuestionPaper extends StatelessWidget {
  final String question;
const _QuestionPaper({required this.question});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 292,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                '請在附近尋找線索，並回答以下問題。',
                textAlign: TextAlign.left,
                style: AppTextStyles.bodySmallMedium.copyWith(color: _hintTextColor).copyWith(height: 1.6, letterSpacing: 0.5, wordSpacing: 0.7),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Text(
                question,
                textAlign: TextAlign.left,
                style: AppTextStyles.titleMediumBold.copyWith(color: _textColor).copyWith(height: 1.45, letterSpacing: 0.45, wordSpacing: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerOption extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _AnswerOption({
    required this.text,
    required this.selected,
    required this.onTap,
});

  @override
  State<_AnswerOption> createState() => _AnswerOptionState();
}

class _AnswerOptionState extends State<_AnswerOption> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.985
        : hovering
        ? 1.008
        : 1.0;

    final Color background = widget.selected
        ? _selectedBackground
        : const Color(0xFFE8D8B8);

    final Color textColor = widget.selected
        ? _selectedTextColor
        : _optionTextColor;

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
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: double.infinity,
            height: 47,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: _answerBorder, width: 1.2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: Offset(5, 5),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: true,
                applyHeightToLastDescent: true,
              ),
              style: AppTextStyles.titleMediumBold.copyWith(color: textColor)
                  .copyWith(
                    height: 1.15,
                    letterSpacing: 0.45,
                    wordSpacing: 0.7,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _SubmitButton({
    required this.text,
    required this.onTap,
});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.97
        : hovering
        ? 1.02
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Container(
            width: 272,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: _buttonBorder, width: 2),
              color: _buttonColor,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMediumBold.copyWith(color: AppColors.paper)
                  .copyWith(height: 1.05, letterSpacing: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClueScrollDialog extends StatefulWidget {
  final String clueText;

  const _ClueScrollDialog({required this.clueText});

  @override
  State<_ClueScrollDialog> createState() => _ClueScrollDialogState();
}

class _ClueScrollDialogState extends State<_ClueScrollDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.78, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                child: Container(color: Colors.black.withOpacity(0.80)),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: SizedBox(
                      width: 330,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRect(
                            child: Align(
                              alignment: Alignment.center,
                              widthFactor: _expandAnimation.value,
                              child: SizedBox(
                                width: 330,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 280,
                                      padding: const EdgeInsets.fromLTRB(
                                        38,
                                        42,
                                        38,
                                        34,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEBDDC4),
                                        border: Border.all(
                                          color: const Color(0xFF8B6947),
                                          width: 1.2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x70000000),
                                            blurRadius: 15,
                                            offset: Offset(0, 7),
                                          ),
                                        ],
                                      ),
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '線索',
                                              textAlign: TextAlign.center,
                                              style:
                                                  AppTextStyles.heroTitle.copyWith(color: const Color(
                                                      0xFF6D2A1D,
                                                    )).copyWith(
                                                    height: 1.2,
                                                    letterSpacing: 2.0,
                                                  ),
                                            ),
                                            const SizedBox(height: 20),
                                            Container(
                                              width: 44,
                                              height: 1,
                                              color: const Color(0xFF9A7854),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              widget.clueText,
                                              textAlign: TextAlign.center,
                                              style:
                                                  AppTextStyles.sectionTitleMedium.copyWith(color: const Color(
                                                      0xFF3D281D,
                                                    )).copyWith(
                                                    height: 1.7,
                                                    letterSpacing: 0.8,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      left: 18,
                                      right: 18,
                                      child: _PaperRoll(width: 294),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 18,
                                      right: 18,
                                      child: _PaperRoll(width: 294),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _close,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                child: Text(
                                  '輕觸空白處關閉',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white).copyWith(height: 1.2, letterSpacing: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperRoll extends StatelessWidget {
  final double width;

  const _PaperRoll({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFD2B98F),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF806044), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 4,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFB5966C),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
            ),
          ),
          Expanded(
            child: Container(height: 20, color: const Color(0xFFD2B98F)),
          ),
          Container(
            width: 18,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFB5966C),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
