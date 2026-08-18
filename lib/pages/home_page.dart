import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../block/navigationbar.dart';
import 'selection_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  String accountName = 'EP001';
  String accountPassword = '';

  static const Color pageColor = Color(0xFFB9ACA2);
  static const Color darkText = Color(0xFF301717);

  static const Color postcardColor = Color(0xFFCBB57C);

  static const Color postcardLine = Color(0xFF8D7B6E);

  // static const Color red = Color(0xFF8D1F12);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,

      extendBody: true,

      body: LayoutBuilder(
        builder: (context, constraints) {
          const double designWidth = 360;
          const double designHeight = 640;

          final double scaleX = constraints.maxWidth / designWidth;

          final double scaleY = constraints.maxHeight / designHeight;

          final double scale = scaleX < scaleY ? scaleX : scaleY;

          return Center(
            child: SizedBox(
              width: designWidth * scale,
              height: designHeight * scale,

              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,

                child: SizedBox(
                  width: designWidth,
                  height: designHeight,

                  child: Stack(
                    clipBehavior: Clip.none,

                    children: [
                      // ==================================================
                      // 1. 背景
                      // ==================================================
                      Positioned.fill(child: Container(color: pageColor)),

                      // ==================================================
                      // 2. 白色虛線
                      // ==================================================
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _HomeDashedPainter()),
                        ),
                      ),

                      // ==================================================
                      // 3. 紅色路線
                      // ==================================================
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _HomeRoutePainter()),
                        ),
                      ),

                      // ==================================================
                      // 4. 徽章收藏
                      // ==================================================
                      Positioned(
                        left: 214,
                        top: 161,
                        width: 128,
                        height: 92,

                        child: _HoverCard(
                          hoverScale: 1.045,

                          child: _BadgeCard(),
                        ),
                      ),

                      // ==================================================
                      // 5. 過往旅途
                      // ==================================================
                      Positioned(
                        left: 15,
                        top: 270,
                        width: 139,
                        height: 198,

                        child: _HoverCard(
                          hoverScale: 1.035,

                          child: _TripPolaroid(),
                        ),
                      ),

                      // ==================================================
                      // 6. 出發探險
                      // ==================================================
                      Positioned(
                        left: 160,
                        top: 282,
                        width: 174,
                        height: 226,

                        child: _HoverCard(
                          hoverScale: 1.035,

                          child: _GoPolaroid(),
                        ),
                      ),

                      // ==================================================
                      // 7. Tape
                      // ==================================================
                      Positioned(
                        left: 48,
                        top: 261,
                        width: 76,
                        height: 28,

                        child: _Tape(rotation: -0.015),
                      ),

                      // ==================================================
                      // 8. 探員資訊
                      // ==================================================
                      Positioned(
                        left: 48,
                        top: 510,
                        width: 105,
                        height: 43,

                        child: _HoverCard(
                          hoverScale: 1.06,

                          child: _AgentInfo(onTap: _showAgentInfoDialog),
                        ),
                      ),

                      // ==================================================
                      // 9. 探員 Tape
                      // ==================================================
                      Positioned(
                        left: 52,
                        top: 494,
                        width: 76,
                        height: 28,

                        child: _Tape(rotation: -0.025),
                      ),

                      // ==================================================
                      // 10. 目前總覽
                      // ==================================================
                      Positioned(
                        left: 20,
                        top: 54,
                        width: 210,
                        height: 170,

                        child: _OverviewCard(),
                      ),

                      // ==================================================
                      // 11. 圖釘
                      // ==================================================
                      const Positioned(left: 116, top: 43, child: _PushPin()),

                      const Positioned(left: 320, top: 165, child: _PushPin()),

                      const Positioned(left: 264, top: 284, child: _PushPin()),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),

      // ================================================================
      // Bottom Navigation
      // ================================================================
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  // ====================================================================
  // 探員資訊彈窗
  // ====================================================================

  void _showAgentInfoDialog() {
    showGeneralDialog(
      context: context,

      barrierDismissible: true,

      barrierLabel: '關閉探員資訊',

      // 黑色 80% 遮罩
      barrierColor: const Color(0xCC000000),

      transitionDuration: const Duration(milliseconds: 280),

      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: animation,

          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.88,
              end: 1.0,
            ).animate(curvedAnimation),

            child: child,
          ),
        );
      },

      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _AgentInfoDialog(
            accountName: accountName,

            accountPassword: accountPassword,

            onEdit: () {
              Navigator.of(context).pop();

              Future.delayed(const Duration(milliseconds: 80), () {
                if (!mounted) return;

                _showEditAccountDialog();
              });
            },

            onLogout: () {
              Navigator.of(context).pop();

              Future.delayed(const Duration(milliseconds: 80), () {
                if (!mounted) return;

                _logout();
              });
            },
          ),
        );
      },
    );
  }

  // ====================================================================
  // 編輯帳號
  // ====================================================================

  void _showEditAccountDialog() {
    final TextEditingController accountController = TextEditingController(
      text: accountName,
    );

    final TextEditingController passwordController = TextEditingController(
      text: accountPassword,
    );

    showGeneralDialog(
      context: context,

      barrierDismissible: true,

      barrierLabel: '關閉編輯',

      barrierColor: const Color(0xCC000000),

      transitionDuration: const Duration(milliseconds: 260),

      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return FadeTransition(
          opacity: animation,

          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.90,
              end: 1.0,
            ).animate(curvedAnimation),

            child: child,
          ),
        );
      },

      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _EditAccountDialog(
            accountController: accountController,

            passwordController: passwordController,

            kaisei: kaisei,

            onSave: () {
              final String newAccount = accountController.text.trim();

              final String newPassword = passwordController.text;

              setState(() {
                if (newAccount.isNotEmpty) {
                  accountName = newAccount;
                }

                accountPassword = newPassword;
              });

              Navigator.of(context).pop();

              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;

                _showAgentInfoDialog();
              });
            },
          ),
        );
      },
    );
  }

  // ====================================================================
  // 登出
  // ====================================================================

  void _logout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ====================================================================
  // 目前總覽
  // ====================================================================

  Widget _OverviewCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),

        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 6,
            offset: Offset(2, 3),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),

        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('img/all_look.png', fit: BoxFit.fill),
            ),

            // ========================================================
            // 標題
            // ========================================================
            Positioned(
              top: 10,
              left: 0,
              right: 0,

              child: Center(
                child: Text(
                  '目前總覽',

                  textAlign: TextAlign.center,

                  style: kaisei(
                    size: 20,
                    weight: FontWeight.w700,
                    color: const Color(0xFF3D342E),
                  ),
                ),
              ),
            ),

            // ========================================================
            // 分隔線
            // ========================================================
            Positioned(
              left: 17,
              right: 17,
              top: 45,

              child: Container(height: 1, color: const Color(0xFF51473F)),
            ),

            // ========================================================
            // 已完成探險
            // ========================================================
            Positioned(
              top: 56,
              left: 0,
              right: 0,

              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Text(
                      '已完成探險',

                      textAlign: TextAlign.center,

                      style: kaisei(size: 13, weight: FontWeight.w700),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      '1',

                      textAlign: TextAlign.center,

                      style: kaisei(
                        size: 27,
                        weight: FontWeight.w700,
                        color: const Color(0xFF8C1D13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ========================================================
            // 明信片
            // ========================================================
            Positioned(
              left: 14,
              top: 94,
              width: 60,

              child: _OverviewNumber(
                title: '明信片',
                number: '10',
                titleColor: postcardLine,
              ),
            ),

            // ========================================================
            // 徽章
            // ========================================================
            Positioned(
              left: 74,
              top: 94,
              width: 60,

              child: _OverviewNumber(
                title: '徽章',
                number: '1',
                titleColor: postcardLine,
              ),
            ),

            // ========================================================
            // VLOG
            // ========================================================
            Positioned(
              left: 134,
              top: 94,
              width: 60,

              child: _OverviewNumber(
                title: 'VLOG',
                number: '1',
                titleColor: postcardLine,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _OverviewNumber({
    required String title,
    required String number,
    required Color titleColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,

      children: [
        Text(
          title,

          textAlign: TextAlign.center,

          style: kaisei(size: 13, weight: FontWeight.w700, color: titleColor),
        ),

        const SizedBox(height: 2),

        Text(
          number,

          textAlign: TextAlign.center,

          style: kaisei(
            size: 28,
            weight: FontWeight.w700,
            color: const Color(0xFF8C1D13),
          ),
        ),
      ],
    );
  }

  // ====================================================================
  // 徽章收藏
  // ====================================================================

  Widget _BadgeCard() {
    return Transform.rotate(
      angle: 0.015,

      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F4EC),

          borderRadius: BorderRadius.circular(6),

          boxShadow: const [
            BoxShadow(
              color: Color(0x45000000),
              blurRadius: 5,
              offset: Offset(2, 3),
            ),
          ],
        ),

        child: Stack(
          children: [
            Positioned(
              left: 9,
              top: 15,
              width: 55,
              height: 55,

              child: Image.asset('img/Badge.png', fit: BoxFit.contain),
            ),

            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 55),

                  child: Text(
                    '徽章收藏',

                    textAlign: TextAlign.center,

                    style: kaisei(
                      size: 13,
                      weight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // Tape
  // ====================================================================

  Widget _Tape({double rotation = 0}) {
    return Transform.rotate(
      angle: rotation,

      child: Opacity(
        opacity: 0.88,

        child: Image.asset('img/tape.png', fit: BoxFit.fill),
      ),
    );
  }

  // ====================================================================
  // 過往旅途
  // ====================================================================

  Widget _TripPolaroid() {
    return Transform.rotate(
      angle: -0.055,

      child: Container(
        decoration: BoxDecoration(
          color: postcardColor,

          borderRadius: BorderRadius.circular(5),

          border: Border.all(color: postcardLine, width: 1),

          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 5,
              offset: Offset(2, 3),
            ),
          ],
        ),

        padding: const EdgeInsets.fromLTRB(7, 7, 7, 10),

        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),

                child: Image.asset(
                  'img/home_trip.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 7),

            SizedBox(
              width: double.infinity,

              child: Text(
                '過往旅途',

                textAlign: TextAlign.center,

                style: kaisei(
                  size: 14,
                  weight: FontWeight.w700,
                  color: darkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // 出發探險
  // ====================================================================
  Widget _GoPolaroid() {
    return _HomeHoverCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SelectionPage()),
        );
      },

      child: Transform.rotate(
        angle: 0.095,

        child: Container(
          decoration: BoxDecoration(
            color: postcardColor,

            borderRadius: BorderRadius.circular(7),

            border: Border.all(color: postcardLine, width: 1),

            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 5,
                offset: Offset(2, 3),
              ),
            ],
          ),

          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),

          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),

                  child: Image.asset(
                    'img/home_gogo.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 7),

              SizedBox(
                width: double.infinity,

                child: Text(
                  '出發探險',
                  textAlign: TextAlign.center,

                  style: kaisei(
                    size: 14,
                    weight: FontWeight.w700,
                    color: darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // 探員資訊
  // ====================================================================

  Widget _AgentInfo({required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(6),

        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F4EC),

            borderRadius: BorderRadius.circular(6),

            border: Border.all(color: postcardLine, width: 1),

            boxShadow: const [
              BoxShadow(
                color: Color(0x45000000),
                blurRadius: 4,
                offset: Offset(1, 2),
              ),
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              const Icon(Icons.settings, size: 20, color: darkText),

              const SizedBox(width: 4),

              Text(
                '探員資訊',

                textAlign: TextAlign.center,

                style: kaisei(
                  size: 13,
                  weight: FontWeight.w700,
                  color: darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Hover Card
// ======================================================================

class _HoverCard extends StatefulWidget {
  final Widget child;

  final double hoverScale;

  const _HoverCard({required this.child, this.hoverScale = 1.035});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
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

      child: AnimatedScale(
        scale: hovering ? widget.hoverScale : 1.0,

        duration: const Duration(milliseconds: 180),

        curve: Curves.easeOut,

        child: widget.child,
      ),
    );
  }
}

// ======================================================================
// 探員資訊彈窗
// ======================================================================

class _AgentInfoDialog extends StatelessWidget {
  final String accountName;

  final String accountPassword;

  final VoidCallback onEdit;

  final VoidCallback onLogout;

  const _AgentInfoDialog({
    required this.accountName,

    required this.accountPassword,

    required this.onEdit,

    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width < 360
        ? MediaQuery.of(context).size.width - 30
        : 320;

    return Material(
      color: Colors.transparent,

      child: SizedBox(
        width: width,
        height: 214,

        child: Stack(
          clipBehavior: Clip.none,

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
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 22, 25, 18),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ====================================================
                  // 標題
                  // ====================================================
                  Row(
                    children: [
                      Image.asset(
                        'img/user_icon.png',

                        width: 25,
                        height: 25,

                        fit: BoxFit.contain,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        '探員帳號',

                        style: GoogleFonts.kaiseiHarunoUmi(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF301717),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ====================================================
                  // 帳號名稱
                  // ====================================================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,

                    children: [
                      Text(
                        '帳號名稱：$accountName',

                        style: GoogleFonts.kaiseiHarunoUmi(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF40342D),
                        ),
                      ),

                      const Spacer(),

                      // 編輯按鈕
                      _EditIconButton(onTap: onEdit),
                    ],
                  ),

                  const Spacer(),

                  // ====================================================
                  // 登出按鈕
                  // ====================================================
                  SizedBox(
                    width: double.infinity,
                    height: 42,

                    child: _PopupButton(text: '登出', onPressed: onLogout),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 編輯帳號彈窗
// ======================================================================

class _EditAccountDialog extends StatelessWidget {
  final TextEditingController accountController;

  final TextEditingController passwordController;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final VoidCallback onSave;

  const _EditAccountDialog({
    required this.accountController,

    required this.passwordController,

    required this.kaisei,

    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width < 360
        ? MediaQuery.of(context).size.width - 30
        : 320;

    return Material(
      color: Colors.transparent,

      child: SizedBox(
        width: width,
        height: 300,

        child: Stack(
          clipBehavior: Clip.none,

          children: [
            // ==========================================================
            // 紙張
            // ==========================================================
            Positioned.fill(
              child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),

              child: Column(
                children: [
                  // ====================================================
                  // 標題
                  // ====================================================
                  Text(
                    '編輯探員資料',

                    textAlign: TextAlign.center,

                    style: kaisei(
                      size: 20,
                      weight: FontWeight.w700,
                      color: const Color(0xFF301717),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ====================================================
                  // 帳號
                  // ====================================================
                  _EditField(
                    controller: accountController,

                    label: '帳號名稱',

                    obscureText: false,
                  ),

                  const SizedBox(height: 12),

                  // ====================================================
                  // 密碼
                  // ====================================================
                  _EditField(
                    controller: passwordController,

                    label: '通行密碼',

                    obscureText: true,
                  ),

                  // const Spacer(),
                  const SizedBox(height: 30),
                  // ====================================================
                  // 儲存
                  // ====================================================
                  SizedBox(
                    width: double.infinity,
                    height: 42,

                    child: _PopupButton(text: '儲存', onPressed: onSave),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// 編輯按鈕 Hover
// ======================================================================

class _EditIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const _EditIconButton({required this.onTap});

  @override
  State<_EditIconButton> createState() => _EditIconButtonState();
}

class _EditIconButtonState extends State<_EditIconButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      // ================================================================
      // 滑鼠移進來
      // ================================================================
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      // ================================================================
      // 滑鼠移出去
      // ================================================================
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        onTap: widget.onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),

          curve: Curves.easeOut,

          width: 42,
          height: 42,

          // ============================================================
          // 圓形底色
          // ============================================================
          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: hovering ? const Color(0xFFD8C8B8) : Colors.transparent,

            boxShadow: hovering
                ? const [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [],
          ),

          child: Center(
            child: AnimatedScale(
              // ========================================================
              // 滑鼠移上去放大
              // ========================================================
              scale: hovering ? 1.20 : 1.0,

              duration: const Duration(milliseconds: 180),

              curve: Curves.easeOut,

              child: Image.asset(
                'img/edit.png',

                width: 27,
                height: 27,

                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ======================================================================
// 編輯欄位
// ======================================================================

class _EditField extends StatelessWidget {
  final TextEditingController controller;

  final String label;

  final bool obscureText;

  const _EditField({
    required this.controller,

    required this.label,

    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,

      obscureText: obscureText,

      textAlign: TextAlign.center,

      style: GoogleFonts.kaiseiHarunoUmi(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF301717),
      ),

      cursorColor: const Color(0xFF8D1F12),

      decoration: InputDecoration(
        labelText: label,

        labelStyle: GoogleFonts.kaiseiHarunoUmi(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6F6258),
        ),

        filled: true,

        fillColor: const Color(0x55FFFFFF),

        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),

          borderSide: const BorderSide(color: Color(0xFF8D7B6E), width: 1),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),

          borderSide: const BorderSide(color: Color(0xFF8D1F12), width: 1.3),
        ),
      ),
    );
  }
}

// ======================================================================
// 彈窗按鈕
// ======================================================================

class _PopupButton extends StatefulWidget {
  final String text;

  final VoidCallback onPressed;

  const _PopupButton({required this.text, required this.onPressed});

  @override
  State<_PopupButton> createState() => _PopupButtonState();
}

class _PopupButtonState extends State<_PopupButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
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

      child: AnimatedScale(
        scale: hovering ? 1.025 : 1.0,

        duration: const Duration(milliseconds: 140),

        child: Material(
          color: Colors.transparent,

          child: InkWell(
            onTap: widget.onPressed,

            borderRadius: BorderRadius.circular(25),

            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),

                color: hovering
                    ? const Color(0xFFA72B16)
                    : const Color(0xFF8D1F12),

                border: Border.all(color: const Color(0xFF551308), width: 1.5),

                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),

                    blurRadius: 4,

                    offset: Offset(0, 2),
                  ),
                ],
              ),

              alignment: Alignment.center,

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
      ),
    );
  }
}

// ======================================================================
// 紅色路線
// ======================================================================

class _HomeRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint redLine = Paint()
      ..color = const Color(0xFF8D1F12)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();

    path.moveTo(126, 54);

    path.lineTo(329, 174);

    path.lineTo(273, 293);

    canvas.drawPath(path, redLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ======================================================================
// 白色虛線
// ======================================================================

class _HomeDashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint whiteDash = Paint()
      ..color = const Color(0xFFEDE6DE)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    _drawDashedLine(
      canvas,
      const Offset(92, 230),
      const Offset(81, 270),
      whiteDash,
    );

    _drawDashedLine(
      canvas,
      const Offset(79, 466),
      const Offset(103, 511),
      whiteDash,
    );

    _drawDashedLine(
      canvas,
      const Offset(153, 529),
      const Offset(211, 500),
      whiteDash,
    );
  }

  void _drawDashedLine(
    Canvas canvas,

    Offset start,

    Offset end,

    Paint paint, {
    double dashLength = 6,

    double gapLength = 7,
  }) {
    final double distance = (end - start).distance;

    final double dx = (end.dx - start.dx) / distance;

    final double dy = (end.dy - start.dy) / distance;

    double current = 0;

    while (current < distance) {
      final double dashStart = current;

      final double dashEnd = math.min(current + dashLength, distance);

      final Offset p1 = Offset(
        start.dx + dx * dashStart,

        start.dy + dy * dashStart,
      );

      final Offset p2 = Offset(
        start.dx + dx * dashEnd,

        start.dy + dy * dashEnd,
      );

      canvas.drawLine(p1, p2, paint);

      current += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ======================================================================
// 首頁卡片 Hover 動畫
// ======================================================================

class _HomeHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HomeHoverCard({required this.child, required this.onTap});

  @override
  State<_HomeHoverCard> createState() => _HomeHoverCardState();
}

class _HomeHoverCardState extends State<_HomeHoverCard> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (hovering) {
      scale = 1.035;
    }

    if (pressing) {
      scale = 0.97;
    }

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
// 圖釘
// ======================================================================

class _PushPin extends StatelessWidget {
  const _PushPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,

      decoration: const BoxDecoration(
        shape: BoxShape.circle,

        gradient: RadialGradient(
          center: Alignment(-0.35, -0.35),

          radius: 0.9,

          colors: [Color(0xFFB93627), Color(0xFF8D1D12), Color(0xFF6F150C)],
        ),

        boxShadow: [
          BoxShadow(
            color: Color(0x80000000),

            blurRadius: 4,

            offset: Offset(2, 3),
          ),
        ],
      ),

      child: Align(
        alignment: Alignment(-0.35, -0.35),

        child: Container(
          width: 5,
          height: 5,

          decoration: const BoxDecoration(
            shape: BoxShape.circle,

            color: Color(0x66FFFFFF),
          ),
        ),
      ),
    );
  }
}
