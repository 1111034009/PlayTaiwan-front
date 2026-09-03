import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import '../block/navigationbar.dart';
import 'home_page.dart';
import 'play_idea_page.dart';
import 'travel_info_page.dart';

class SelectionPage extends StatefulWidget {
  const SelectionPage({super.key});

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
  // ==================================================================
  // Colors
  // ==================================================================

  static const Color pageColor = AppColors.background;

  static const Color darkText = AppColors.textPrimary;

  static const Color red = AppColors.primaryAccent;

  // ==================================================================
  // Design Size
  // ==================================================================

  static const double designWidth = 360;

  static const double designHeight = 640;

  // ==================================================================
  // Navigation Index
  // ==================================================================

  int currentIndex = 0;

  // ==================================================================
  // 地區
  // ==================================================================

  String fakeLocation = '';

  // ==================================================================
  // 地區輸入框
  // ==================================================================

  final TextEditingController locationController = TextEditingController();

  // ==================================================================
  // 一句話輸入框
  // ==================================================================

  final TextEditingController ideaController = TextEditingController();

  // ==================================================================
  // System UI
  // ==================================================================

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ==================================================================
  // Dispose
  // ==================================================================

  @override
  void dispose() {
    locationController.dispose();
    ideaController.dispose();
    super.dispose();
  }

  // ==================================================================
  // 使用當前定位
  // ==================================================================

  void useCurrentLocation() {
    setState(() {
      fakeLocation = '臺中市';

      locationController.text = fakeLocation;

      locationController.selection = TextSelection.fromPosition(
        TextPosition(offset: locationController.text.length),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '目前位置：$fakeLocation',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
        ),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================================================================
  // 解析地區
  // ==================================================================

  Map<String, String> _parseLocation(String input) {
    final String text = input.trim();

    if (text.isEmpty) {
      return {'cityName': '', 'townName': ''};
    }

    final List<String> parts = text
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return {'cityName': parts[0], 'townName': parts[1]};
    }

    return {'cityName': text, 'townName': ''};
  }

  // ==================================================================
  // 現在揪出發
  // ==================================================================

  void startAdventure() {
    fakeLocation = locationController.text.trim();

    if (fakeLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '請先輸入地區',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      return;
    }

    final Map<String, String> location = _parseLocation(fakeLocation);

    final String cityName = location['cityName'] ?? '';

    final String townName = location['townName'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TravelInfoPage(cityName: cityName, townName: townName),
      ),
    );
  }

  // ==================================================================
  // 來點遊意思
  // ==================================================================

  void randomAdventure() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayIdeaPage()),
    );
  }

  // ==================================================================
  // 遊你說了算
  // ==================================================================

  void customAdventure() {
    final String idea = ideaController.text.trim();

    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '先說點什麼吧！',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TravelInfoPage(cityName: '', townName: ''),
      ),
    );
  }

  // ==================================================================
  // 回首頁
  // ==================================================================

  void goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  // ==================================================================
  // Build
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      extendBody: true,

      // ================================================================
      // Body
      // ================================================================
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
                // ======================================================
                // 背景
                // ======================================================

                Positioned.fill(child: Container(color: pageColor)),

                // ======================================================
                // 第一張紙
                //
                // 現在揪出發
                // ======================================================
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 210,
                      child: _AdventurePaper(
                        child: _StartAdventureContent(
                          locationController: locationController,
                          onLocationChanged: (value) {
                            fakeLocation = value;
                          },
                          onLocationPressed: useCurrentLocation,
                          onPressed: startAdventure,
                        ),
                      ),
                    ),
                  ),
                ),

                // ======================================================
                // 第二張紙
                //
                // 來點遊意思
                // ======================================================
                Positioned(
                  top: 230,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 180,
                      child: _AdventurePaper(
                        child: _RandomAdventureContent(
                          onPressed: randomAdventure,
                        ),
                      ),
                    ),
                  ),
                ),

                // ======================================================
                // 第三張紙
                //
                // 遊你說了算
                // ======================================================
                Positioned(
                  top: 420,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 180,
                      child: _AdventurePaper(
                        child: _CustomAdventureContent(
                          ideaController: ideaController,
                          onPressed: customAdventure,
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

      // ================================================================
      // Navigation Bar
      // ================================================================
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ======================================================================
// 紙張外框
// ======================================================================

class _AdventurePaper extends StatelessWidget {
  final Widget child;

  const _AdventurePaper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 6,
            offset: Offset(2, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            // ==========================================================
            // 紙張
            // ==========================================================

            Positioned.fill(
              child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
            ),

            // ==========================================================
            // 內容
            // ==========================================================
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 現在揪出發
// ======================================================================

class _StartAdventureContent extends StatelessWidget {
  final TextEditingController locationController;

  final ValueChanged<String> onLocationChanged;

  final VoidCallback onLocationPressed;

  final VoidCallback onPressed;

  const _StartAdventureContent({
    required this.locationController,
    required this.onLocationChanged,
    required this.onLocationPressed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // 標題
          // ============================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'img/quill_pen.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 7),

              Text(
                '現在揪出發',
                textAlign: TextAlign.left,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ============================================================
          // 地區標題
          // ============================================================
          Text(
            '輸入指定的地區，現在揪出發',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.mutedText,
            ),
          ),

          const SizedBox(height: 15),

          // ============================================================
          // 地區輸入框
          // ============================================================
          SizedBox(
            height: 22,
            child: TextField(
              controller: locationController,
              onChanged: onLocationChanged,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              cursorColor: AppColors.primaryAccent,
              style: AppTextStyles.bodyEmphasisBold.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '例如：臺中市 西屯區',
                hintStyle: AppTextStyles.bodyCompact.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ),

          // ============================================================
          // 底線
          // ============================================================
          Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xFF514A44),
          ),

          const SizedBox(height: 5),

          // ============================================================
          // 使用當前定位
          // ============================================================
          Align(
            alignment: Alignment.centerLeft,
            child: _LocationButton(onTap: onLocationPressed),
          ),

          const Spacer(),

          // ============================================================
          // 開始
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: _RedStartButton(text: '開始', onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// 使用當前定位
// ======================================================================

class _LocationButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LocationButton({required this.onTap});

  @override
  State<_LocationButton> createState() => _LocationButtonState();
}

class _LocationButtonState extends State<_LocationButton> {
  bool hovering = false;

  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (hovering) {
      scale = 1.08;
    }

    if (pressing) {
      scale = 0.96;
    }

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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '使用當前定位',
                textAlign: TextAlign.left,
                style: AppTextStyles.bodyEmphasisBold.copyWith(
                  color: AppColors.primaryAccent,
                ),
              ),
              const SizedBox(width: 3),
              Image.asset(
                'img/gps.png',
                width: 35,
                height: 25,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// 來點遊意思
// ======================================================================

class _RandomAdventureContent extends StatelessWidget {
  final VoidCallback onPressed;

  const _RandomAdventureContent({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // 標題
          // ============================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'img/user_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 7),

              Text(
                '來點遊意思',
                textAlign: TextAlign.left,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // ============================================================
          // 說明
          // ============================================================
          Text(
            '轉動命運的轉盤，來點遊意思',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.mutedText,
            ),
          ),

          const Spacer(),

          // ============================================================
          // 開始
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: _RedStartButton(text: '開始', onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// 遊你說了算
// ======================================================================

class _CustomAdventureContent extends StatelessWidget {
  final TextEditingController ideaController;

  final VoidCallback onPressed;

  const _CustomAdventureContent({
    required this.ideaController,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============================================================
          // 標題
          // ============================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'img/talk_play.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 7),

              Text(
                '遊你說了算',
                textAlign: TextAlign.left,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ============================================================
          // 副標題
          // ============================================================
          Text(
            '你說出口的旅行，遊你說了算',
            textAlign: TextAlign.left,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.mutedText,
            ),
          ),

          const SizedBox(height: 10),

          // ============================================================
          // 輸入框
          // ============================================================
          SizedBox(
            height: 24,
            child: TextField(
              controller: ideaController,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              cursorColor: AppColors.primaryAccent,
              style: AppTextStyles.bodyEmphasisBold.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '例如：想來一趟美食之旅',
                hintStyle: AppTextStyles.bodyCompact.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ),
          ),

          Container(
            height: 1,
            width: double.infinity,
            color: const Color(0xFF514A44),
          ),

          const Spacer(),

          // ============================================================
          // 開始
          // ============================================================
          Align(
            alignment: Alignment.centerRight,
            child: _RedStartButton(text: '開始', onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Hover Scale
// ======================================================================

class _HoverScaleButton extends StatefulWidget {
  final Widget child;

  final VoidCallback onTap;

  const _HoverScaleButton({required this.child, required this.onTap});

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool hovering = false;

  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (hovering) {
      scale = 1.18;
    }

    if (pressing) {
      scale = 1.08;
    }

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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

// ======================================================================
// 紅色按鈕
// ======================================================================

class _RedStartButton extends StatefulWidget {
  final String text;

  final VoidCallback onPressed;

  final double? width;

  const _RedStartButton({
    required this.text,
    required this.onPressed,
    this.width,
  });

  @override
  State<_RedStartButton> createState() => _RedStartButtonState();
}

class _RedStartButtonState extends State<_RedStartButton> {
  bool hovering = false;

  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (hovering) {
      scale = 1.07;
    }

    if (pressing) {
      scale = 0.96;
    }

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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            width: widget.width ?? 70,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              border: Border.all(color: AppColors.primaryDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x70000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
