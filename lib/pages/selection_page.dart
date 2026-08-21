import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';

import '../block/navigationbar.dart';
import 'home_page.dart';
import 'play_idea_page.dart';

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

  static const Color darkText = Color(0xFF301717);

  static const Color red = Color(0xFF8D1F12);

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
  //
  // 預設保持空白
  // ==================================================================

  final TextEditingController locationController = TextEditingController();

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
    super.dispose();
  }

  // ==================================================================
  // Font
  // ==================================================================

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

  // ==================================================================
  // 使用當前定位
  // ==================================================================

  void useCurrentLocation() {
    setState(() {
      fakeLocation = '臺中市 西屯區';

      // 同步更新輸入框
      locationController.text = fakeLocation;

      // 游標移到文字最後面
      locationController.selection = TextSelection.fromPosition(
        TextPosition(offset: locationController.text.length),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '目前位置：$fakeLocation',
          textAlign: TextAlign.center,
          style: kaisei(size: 14, weight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================================================================
  // 現在揪出發
  // ==================================================================

  void startAdventure() {
    fakeLocation = locationController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fakeLocation.isEmpty ? '請先輸入地區' : '準備前往 $fakeLocation 探險！',
          textAlign: TextAlign.center,
          style: kaisei(size: 14, weight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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

      // ================================================================
      // 允許 NavigationBar 疊到 Body 上方
      // ================================================================
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
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 218,
                      child: _AdventurePaper(
                        child: _StartAdventureContent(
                          kaisei: kaisei,
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
                  top: 322,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 324,
                      height: 205,
                      child: _AdventurePaper(
                        child: _RandomAdventureContent(
                          kaisei: kaisei,
                          onPressed: randomAdventure,
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
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final TextEditingController locationController;

  final ValueChanged<String> onLocationChanged;

  final VoidCallback onLocationPressed;

  final VoidCallback onPressed;

  const _StartAdventureContent({
    required this.kaisei,
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
                style: kaisei(size: 21, weight: FontWeight.w700),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ============================================================
          // 地區標題
          // ============================================================
          Text(
            '請輸入地區',
            textAlign: TextAlign.left,
            style: kaisei(
              size: 14,
              weight: FontWeight.w700,
              color: const Color(0xFF8B837B),
            ),
          ),

          const SizedBox(height: 1),

          // ============================================================
          // 地區輸入框
          //
          // 預設沒有文字
          // ============================================================
          SizedBox(
            height: 22,
            child: TextField(
              controller: locationController,

              onChanged: onLocationChanged,

              textInputAction: TextInputAction.done,

              maxLines: 1,

              cursorColor: const Color(0xFF8D1F12),

              style: kaisei(
                size: 15,
                weight: FontWeight.w700,
                color: const Color(0xFF301717),
              ),

              decoration: InputDecoration(
                isDense: true,

                contentPadding: EdgeInsets.zero,

                border: InputBorder.none,

                enabledBorder: InputBorder.none,

                focusedBorder: InputBorder.none,

                hintText: '例如：臺中市 西屯區',

                hintStyle: kaisei(
                  size: 15,
                  weight: FontWeight.w400,
                  color: const Color(0xFF8B837B),
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
            child: _LocationButton(onTap: onLocationPressed, kaisei: kaisei),
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

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _LocationButton({required this.onTap, required this.kaisei});

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
                style: widget.kaisei(
                  size: 15,
                  weight: FontWeight.w700,
                  color: const Color(0xFF8D1F12),
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
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final VoidCallback onPressed;

  const _RandomAdventureContent({
    required this.kaisei,
    required this.onPressed,
  });

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
                style: kaisei(size: 21, weight: FontWeight.w700),
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
            style: kaisei(
              size: 14,
              weight: FontWeight.w700,
              color: const Color(0xFF8B837B),
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
                colors: [Color(0xFF9B2A15), Color(0xFF7D1907)],
              ),

              border: Border.all(color: const Color(0xFF4A1106), width: 2),

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
              style: GoogleFonts.kaiseiHarunoUmi(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
