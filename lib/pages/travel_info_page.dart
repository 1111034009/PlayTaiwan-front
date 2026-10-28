import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_notice.dart';
import '../core/app_text_styles.dart';
import '../api/story_api.dart';
import '../block/navigationbar.dart';
import '../block/script_generating_overlay.dart';
import 'choose_script_page.dart';
import 'dart:async';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;
const Color _optionColor = AppColors.storyBackground;

const Color _redrawBorder = AppColors.primaryDark;
const Color _redrawCenter = AppColors.primaryLight;
const Color _redrawOuter = AppColors.primary;

class TravelInfoPage extends StatefulWidget {
  final String cityName;
  final String townName;

  const TravelInfoPage({
    super.key,
    required this.cityName,
    required this.townName,
  });

  @override
  State<TravelInfoPage> createState() => _TravelInfoPageState();
}

class _TravelInfoPageState extends State<TravelInfoPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  int currentIndex = 1;
  Timer? _progressTimer;

  List<double> segmentProgress = [0];
  final ValueNotifier<List<double>> _segmentsNotifier =
      ValueNotifier<List<double>>([0]);

  DateTime _segStart = DateTime.now();
  int _lastFinished = 0;
  final TextEditingController peopleController = TextEditingController();

  final Set<String> selectedPreferences = {};
  final Set<String> selectedTransports = {};

  bool isGenerating = false;
  double maxTravelMinutes = 30;
  int generatingTotal = 0;
  int generatingFinished = 0;

  String get generatingDetail => '約需 3～5 分鐘，請稍候';
  int generatingStep = 0;
  String generatingText = '正在整理旅程線索';
  Map<String, dynamic>? generatedScript;
  int partySize = 1;

  void _startSegments() {
    _progressTimer?.cancel();
    _segStart = DateTime.now();
    _lastFinished = 0;

    segmentProgress = [0];
    _segmentsNotifier.value = segmentProgress;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;

      final next = List<double>.from(segmentProgress);

      for (int i = 0; i < next.length; i++) {
        if (i < generatingFinished) {
          next[i] = (next[i] + 0.12).clamp(0.0, 1.0);
        } else if (i == generatingFinished) {
          final double t =
              DateTime.now().difference(_segStart).inMilliseconds / 240000;
          final double target = (t * 0.95).clamp(0.0, 0.95);

          if (target > next[i]) {
            next[i] = target;
          }
        }
      }

      final String text = (generatingFinished == 0 && next[0] < 0.5)
          ? '紫薯編找資料中…'
          : '紫薯編寫劇本中…';

      segmentProgress = next;
      _segmentsNotifier.value = next;

      if (text != generatingText) {
        setState(() => generatingText = text);
      }
    });
  }

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
    _progressTimer?.cancel();
    peopleController.dispose();
    _segmentsNotifier.dispose();
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
    if (value == '台灣好行') {
      if (selectedTransports.contains(value)) {
        setState(() => selectedTransports.clear());
      } else {
        setState(() {
          selectedTransports
            ..clear()
            ..add(value);
        });
        _showMessage('因會針對台灣好行航線設計，因此此交通選項只能單選');
      }
      return;
    }

    if (selectedTransports.contains('台灣好行')) {
      _showMessage('已選擇台灣好行，請先取消才能選其他交通方式');
      return;
    }

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

    if (peopleCount == null || peopleCount <= 0 || peopleCount > 999) {
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

    partySize = peopleCount;

    setState(() {
      isGenerating = true;
      generatingText = '紫薯編找資料中…';
      generatingTotal = 0;
      generatingFinished = 0;
    });

    _startSegments();

    try {
      final Map<String, dynamic> result =
          await StoryApi.generateScriptBlueprint(
            cityName: widget.cityName,
            townName: widget.townName.trim().isEmpty
                ? null
                : widget.townName.trim(),
            travelerCount: peopleCount,
            preferences: selectedPreferences.toList(),
            transportation: selectedTransports.toList(),
            maxTravelMinutes: maxTravelMinutes.round(),
            onProgress: (total, finished) {
              if (!mounted) return;
              if (finished != _lastFinished) {
                _lastFinished = finished;
                _segStart = DateTime.now();
              }
              setState(() {
                generatingTotal = total;
                generatingFinished = finished;
              });
            },
          );

      if (!mounted) {
        return;
      }

      setState(() {
        generatedScript = result;
      });

      _progressTimer?.cancel();
      setState(() {
        segmentProgress = [1];
        _segmentsNotifier.value = segmentProgress;
        generatingText = '劇本生成完成';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      setState(() => isGenerating = false);
      _showScriptCompleteDialog();
    } catch (e) {
      _progressTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        isGenerating = false;
        segmentProgress = [0];
        _segmentsNotifier.value = segmentProgress;
      });

      _showMessage('劇本生成失敗，請稍後再試');
    }
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
                          builder: (context) => ChooseScriptPage(
                            generatedScript: generatedScript,
                            cityName: widget.cityName,
                            townName: widget.townName,
                            transportation: selectedTransports.toList(),
                            partySize: partySize,
                          ),
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
                      style: AppTextStyles.bodyEmphasisBold.copyWith(
                        color: Colors.white,
                      ),
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
    AppNotice.show(message);
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
                            top: 10,
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
                                  const SizedBox(width: 5),
                                  _OutlinedTitle(text: '組隊集結'),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 60,
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
                                  style: AppTextStyles.bodyEmphasisBold
                                      .copyWith(color: _darkBrown),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 13,
                            top: 120,
                            width: 334,
                            height: 530,
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
                            top: 150,
                            width: 282,
                            child: _FormContent(
                              peopleController: peopleController,
                              selectedPreferences: selectedPreferences,
                              selectedTransports: selectedTransports,
                              onPreferenceTap: togglePreference,
                              onTransportTap: toggleTransport,
                              onGenerate: generateScript,
                              maxTravelMinutes: maxTravelMinutes,
                              onMaxTravelChanged: (value) {
                                setState(() {
                                  maxTravelMinutes = value;
                                });
                              },
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
            child: ValueListenableBuilder<List<double>>(
              valueListenable: _segmentsNotifier,
              builder: (_, segs, __) => ScriptGeneratingOverlay(
                message: generatingText,
                progress: 0,
                segments: segs,
                detail: generatingDetail.isEmpty ? null : generatingDetail,
                stage: generatingText.contains('找資料') ? 0 : 1,
              ),
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
    final TextStyle outlineStyle = AppTextStyles.displayLarge
        .copyWith(color: _darkBrown)
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
  final double maxTravelMinutes;
  final ValueChanged<double> onMaxTravelChanged;

  const _FormContent({
    required this.peopleController,
    required this.selectedPreferences,
    required this.selectedTransports,
    required this.onPreferenceTap,
    required this.onTransportTap,
    required this.onGenerate,
    required this.maxTravelMinutes,
    required this.onMaxTravelChanged,
  });

  Widget choice({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: _ChoiceButton(text: text, selected: selected, onTap: onTap),
    );
  }

  Widget transportChoice({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bool dimmed = text != '台灣好行' && selectedTransports.contains('台灣好行');
    return SizedBox(
      width: 88.666,
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        child: _ChoiceButton(text: text, selected: selected, onTap: onTap),
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            textAlign: TextAlign.left,
            style: AppTextStyles.bodyEmphasisBold.copyWith(color: _darkText),
            cursorColor: _optionColor,
            decoration: InputDecoration(
              hintText: '請輸入數字',
              hintStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.mutedText,
              ),
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
        const SizedBox(height: 8),
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
              text: '台灣好行',
              selected: selectedTransports.contains('台灣好行'),
              onTap: () => onTransportTap('台灣好行'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '接受的最長交通時間',
              style: AppTextStyles.sectionTitle.copyWith(color: _darkText),
            ),
            const Spacer(),
            Text(
              '${maxTravelMinutes.round()} 分鐘',
              style: AppTextStyles.bodySmallBold.copyWith(color: _optionColor),
            ),
          ],
        ),
        SizedBox(
          height: 30,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: _optionColor,
              inactiveTrackColor: _optionColor.withOpacity(0.25),
              thumbColor: _redrawCenter,
              overlayColor: _redrawCenter.withOpacity(0.15),
            ),
            child: Slider(
              value: maxTravelMinutes,
              min: 10,
              max: 60,
              divisions: 10,
              onChanged: onMaxTravelChanged,
            ),
          ),
        ),
        const SizedBox(height: 5),
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
              style: AppTextStyles.bodySmallBold.copyWith(
                color: widget.selected ? Colors.white : _optionColor,
              ),
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
              style: AppTextStyles.bodyCompactBold.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
