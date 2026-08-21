import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';

// ================================================================
// Login Page
// ================================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController accountController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  static const Color pageColor = AppColors.background;
  static const Color darkText = AppColors.textPrimary;
  static const Color lineColor = AppColors.inputLine;

  static const Color cursorColor = AppColors.primary;

  static const Color hintColor = AppColors.inputHint;

  // ==============================================================
  // Design Size

  static const double designWidth = 360;
  static const double designHeight = 640;

  // ==============================================================
  // System UI
  // ==============================================================

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

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // ==============================================================
  // Login
  // ==============================================================

  void login() {
    Navigator.pushReplacementNamed(context, '/user-type');
  }

  // ==============================================================
  // Font
  // ==============================================================

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

  InputDecoration inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,

      hintStyle: kaisei(size: 14, color: hintColor),

      contentPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),

      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: lineColor, width: 1),
      ),

      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: lineColor, width: 1),
      ),

      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: lineColor, width: 1),
      ),
    );
  }

  // ==============================================================
  // Section Title

  Widget sectionTitle({
    required String icon,
    required String title,
    required double top,
  }) {
    return Positioned(
      top: top,
      left: 46,

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Image.asset(icon, width: 23, height: 23),

          const SizedBox(width: 7),

          Text(title, style: kaisei(size: 15, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ==============================================================
  // Build
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,

      // ============================================================
      // Responsive Scaling
      // ============================================================
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
                Positioned.fill(child: Container(color: pageColor)),

                // ==================================================
                // NPC
                // ==================================================
                Positioned(
                  left: 0,
                  right: 0,
                  top: 45,
                  height: 195,

                  child: IgnorePointer(
                    child: Center(
                      child: Image.asset(
                        'img/login_top_npc.png',
                        width: 292.5,
                        height: 266.5,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // 白色紙張
                // ==================================================
                Positioned(
                  left: 13,
                  right: 13,
                  top: 184,
                  height: 402,

                  child: Image.asset('img/notepaper.png', fit: BoxFit.fill),
                ),

                // ==================================================
                // TOP SECRET
                // ==================================================
                Positioned(
                  top: 198,
                  left: 30,
                  width: 137,
                  height: 42,

                  child: Image.asset(
                    'img/stamp.png',
                    width: 137,
                    height: 42,
                    fit: BoxFit.contain,
                  ),
                ),

                // ==================================================
                // 主標題
                // ==================================================
                Positioned(
                  top: 263,
                  left: 20,
                  right: 20,

                  child: Center(
                    child: Text(
                      '日遊所思，夜遊所夢',

                      textAlign: TextAlign.center,

                      style: kaisei(
                        size: 22,
                        weight: FontWeight.w700,
                        color: const Color(0xFF292522),
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // Play Taiwan
                // ==================================================
                Positioned(
                  top: 292,
                  left: 20,
                  right: 20,

                  child: Center(
                    child: Text(
                      'Play Taiwan',

                      textAlign: TextAlign.center,

                      style: kaisei(
                        size: 14,
                        weight: FontWeight.w700,
                        color: const Color(0xFF66615C),
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // 使用者標題
                // ==================================================
                sectionTitle(icon: 'img/user.png', title: '探險代號', top: 325),

                // ==================================================
                // 帳號
                // ==================================================
                Positioned(
                  left: 46,
                  right: 46,
                  top: 356,
                  height: 40,

                  child: TextField(
                    controller: accountController,

                    textAlign: TextAlign.center,

                    style: kaisei(size: 14, color: darkText),

                    cursorColor: cursorColor,

                    decoration: inputDecoration(hintText: '請輸入帳號'),
                  ),
                ),

                // ==================================================
                // 密碼標題
                // ==================================================
                sectionTitle(icon: 'img/password.png', title: '通行密碼', top: 412),

                // ==================================================
                // 密碼
                // ==================================================
                Positioned(
                  left: 46,
                  right: 46,
                  top: 443,
                  height: 40,

                  child: TextField(
                    controller: passwordController,

                    obscureText: true,

                    textAlign: TextAlign.center,

                    style: kaisei(size: 14, color: darkText),

                    cursorColor: cursorColor,

                    decoration: inputDecoration(hintText: '請輸入密碼'),
                  ),
                ),

                // ==================================================
                // 登入按鈕
                // ==================================================
                Positioned(
                  top: 506,
                  left: 0,
                  right: 0,
                  height: 49,

                  child: Center(
                    child: SizedBox(
                      width: 90,
                      height: 49,

                      child: _LoginButton(onPressed: login),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// Login Button
// ==================================================================

class _LoginButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _LoginButton({required this.onPressed});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool isPressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ----------------------------------------------------------
      // Click
      // ----------------------------------------------------------
      onTap: widget.onPressed,

      // ----------------------------------------------------------
      // Press
      // ----------------------------------------------------------
      onTapDown: (_) {
        setState(() {
          isPressing = true;
        });
      },

      onTapUp: (_) {
        setState(() {
          isPressing = false;
        });
      },

      onTapCancel: () {
        setState(() {
          isPressing = false;
        });
      },

      child: AnimatedScale(
        scale: isPressing ? 0.96 : 1.0,

        duration: const Duration(milliseconds: 180),

        curve: Curves.easeOut,

        child: Material(
          color: Colors.transparent,

          child: InkWell(
            onTap: widget.onPressed,

            borderRadius: BorderRadius.circular(30),

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),

              curve: Curves.easeOut,

              width: 90,
              height: 49,

              alignment: Alignment.center,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),

                // ------------------------------------------------
                // Border
                // ------------------------------------------------
                border: Border.all(color: AppColors.primaryDark, width: 2),

                // ------------------------------------------------
                // Gradient
                // ------------------------------------------------
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,

                  colors: const [AppColors.primaryLight, AppColors.primary],
                ),

                // ------------------------------------------------
                // Shadow
                // ------------------------------------------------
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x70000000),

                    blurRadius: 4,

                    offset: const Offset(0, 2),
                  ),
                ],
              ),

              // --------------------------------------------------
              // Button Text
              // --------------------------------------------------
              child: Text(
                '登入',

                textAlign: TextAlign.center,

                style: GoogleFonts.kaiseiHarunoUmi(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
