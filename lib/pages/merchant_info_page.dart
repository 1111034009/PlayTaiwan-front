import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _pageColor = Color(0xFFB9ACA2);
const Color _paperColor = Color(0xFFFCF9EA);
const Color _paperBorder = Color(0xFF000000);
const Color _darkText = Color(0xFF301717);
const Color _bodyText = Color(0xFF2F2D28);

const Color _buttonBorder = Color(0xFF4A1106);
const Color _buttonCenter = Color(0xFF9B2A15);
const Color _buttonOuter = Color(0xFF7D1907);

const Color _accentRed = Color(0xFF7F1A08);

// ============================================================
// 資訊設定「彈窗內容」
// ============================================================

class MerchantInfoPage extends StatefulWidget {
  const MerchantInfoPage({super.key});

  @override
  State<MerchantInfoPage> createState() => _MerchantInfoPageState();
}

class _MerchantInfoPageState extends State<MerchantInfoPage> {
  // ============================================================
  // 使用者資料
  // ============================================================

  String accountName = 'EP001';

  String shopName = '日式復古串燒居酒屋';

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

  // ============================================================
  // 字體
  // ============================================================

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _darkText,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // ============================================================
  // 編輯帳號名稱
  // ============================================================

  Future<void> editAccount() async {
    final String? result = await _showEditDialog(
      title: '編輯帳號名稱',
      label: '帳號名稱',
      initialValue: accountName,
    );

    if (!mounted) {
      return;
    }

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        accountName = result.trim();
      });
    }
  }

  // ============================================================
  // 編輯店家名稱
  // ============================================================

  Future<void> editShop() async {
    final String? result = await _showEditDialog(
      title: '編輯店家名稱',
      label: '店家名稱',
      initialValue: shopName,
    );

    if (!mounted) {
      return;
    }

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        shopName = result.trim();
      });
    }
  }

  // ============================================================
  // 編輯文字彈窗
  // ============================================================

  Future<String?> _showEditDialog({
    required String title,
    required String label,
    required String initialValue,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );

    final String? result = await showDialog<String>(
      context: context,

      // 點擊外面可以關閉
      barrierDismissible: true,

      // 編輯彈窗本身也使用較深的壓暗
      barrierColor: const Color(0xDD000000),

      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 24,
          ),
          child: Container(
            width: 310,

            padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),

            decoration: BoxDecoration(
              color: _paperColor,

              borderRadius: BorderRadius.circular(5),

              border: Border.all(color: Colors.black, width: 1.3),

              boxShadow: const [
                BoxShadow(
                  color: _darkText,
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: Offset(2, 3),
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // 標題
                // ==================================================
                Text(
                  title,
                  style: kaisei(
                    size: 22,
                    weight: FontWeight.w900,
                    color: Colors.black,
                  ).copyWith(height: 1.0),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // 欄位名稱
                // ==================================================
                Text(
                  label,
                  style: kaisei(
                    size: 15,
                    weight: FontWeight.w700,
                    color: _bodyText,
                  ),
                ),

                const SizedBox(height: 7),

                // ==================================================
                // 輸入框
                // ==================================================
                TextField(
                  controller: controller,

                  autofocus: true,

                  maxLength: 30,

                  textInputAction: TextInputAction.done,

                  style: kaisei(
                    size: 17,
                    weight: FontWeight.w700,
                    color: _bodyText,
                  ),

                  decoration: InputDecoration(
                    counterText: '',

                    filled: true,

                    fillColor: Colors.white,

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.2,
                      ),
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.2,
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: const BorderSide(color: _accentRed, width: 2),
                    ),
                  ),

                  // 鍵盤 Enter / Done
                  onSubmitted: (value) {
                    final String text = value.trim();

                    if (text.isEmpty) {
                      return;
                    }

                    Navigator.pop(dialogContext, text);
                  },
                ),

                const SizedBox(height: 18),

                // ==================================================
                // 取消 / 儲存
                // ==================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,

                  children: [
                    // ------------------------------------------------
                    // 取消
                    // ------------------------------------------------
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },

                      child: Text(
                        '取消',
                        style: kaisei(
                          size: 15,
                          weight: FontWeight.w700,
                          color: _bodyText,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ------------------------------------------------
                    // 儲存
                    // ------------------------------------------------
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentRed,
                        foregroundColor: _paperColor,

                        elevation: 2,

                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),

                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                      ),

                      onPressed: () {
                        final String value = controller.text.trim();

                        if (value.isEmpty) {
                          return;
                        }

                        Navigator.pop(dialogContext, value);
                      },

                      child: Text(
                        '儲存',
                        style: kaisei(
                          size: 15,
                          weight: FontWeight.w700,
                          color: _paperColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    return result;
  }

  // ============================================================
  // 登出
  // ============================================================

  void logout() {
    Navigator.pop(context);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,

      elevation: 0,

      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),

      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330, maxHeight: 405),

        child: SizedBox(
          width: 330,
          height: 405,

          child: _InfoCard(
            accountName: accountName,
            shopName: shopName,

            kaisei: kaisei,

            onEditAccount: editAccount,
            onEditShop: editShop,
            onLogout: logout,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 資訊設定紙張
// ============================================================

class _InfoCard extends StatelessWidget {
  final String accountName;

  final String shopName;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final VoidCallback onEditAccount;

  final VoidCallback onEditShop;

  final VoidCallback onLogout;

  const _InfoCard({
    required this.accountName,
    required this.shopName,
    required this.kaisei,
    required this.onEditAccount,
    required this.onEditShop,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,

      children: [
        // ========================================================
        // 紙張
        // ========================================================
        Container(
          width: double.infinity,
          height: double.infinity,

          padding: const EdgeInsets.fromLTRB(25, 40, 25, 22),

          decoration: BoxDecoration(
            color: _paperColor,

            borderRadius: BorderRadius.circular(5),

            border: Border.all(color: _paperBorder, width: 1.3),

            boxShadow: const [
              BoxShadow(
                color: _darkText,
                blurRadius: 0,
                spreadRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // 帳號資訊
              // ==================================================
              _SectionTitle(
                icon: 'img/user_icon.png',
                title: '帳號資訊',
                kaisei: kaisei,
              ),

              const SizedBox(height: 14),

              _InfoRow(
                text: '帳號名稱：$accountName',
                showEdit: true,
                onEdit: onEditAccount,
                kaisei: kaisei,
              ),

              const SizedBox(height: 25),

              // ==================================================
              // 預設資訊
              // ==================================================
              _SectionTitle(
                icon: 'img/shop_icon.png',
                title: '預設資訊',
                kaisei: kaisei,
              ),

              const SizedBox(height: 14),

              _InfoRow(
                text: '店家名稱：',
                showEdit: false,
                onEdit: onEditShop,
                kaisei: kaisei,
              ),

              const SizedBox(height: 3),

              _InfoRow(
                text: shopName,
                showEdit: true,
                onEdit: onEditShop,
                kaisei: kaisei,
              ),

              const SizedBox(height: 15),

              // ==================================================
              // 輸出格式
              // ==================================================
              Text(
                '輸出格式：9:16',
                style: kaisei(
                  size: 18,
                  weight: FontWeight.w700,
                  color: _bodyText,
                ).copyWith(height: 1.15),
              ),

              // ==================================================
              // 登出推到底
              // ==================================================
              const Spacer(),

              Center(
                child: _LogoutButton(
                  text: '登出',
                  onTap: onLogout,
                  kaisei: kaisei,
                ),
              ),
            ],
          ),
        ),

        // ========================================================
        // 上方紅色 Pin
        // ========================================================
        const Positioned(
          top: 7,
          left: 0,
          right: 0,
          child: Center(child: _Pin()),
        ),
      ],
    );
  }
}

// ============================================================
// 區塊標題
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String icon;

  final String title;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Image.asset(icon, width: 27, height: 27, fit: BoxFit.contain),

        const SizedBox(width: 7),

        Text(
          title,
          style: kaisei(
            size: 23,
            weight: FontWeight.w900,
            color: Colors.black,
          ).copyWith(height: 1.0),
        ),
      ],
    );
  }
}

// ============================================================
// 資訊列
// ============================================================

class _InfoRow extends StatelessWidget {
  final String text;

  final bool showEdit;

  final VoidCallback onEdit;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _InfoRow({
    required this.text,
    required this.showEdit,
    required this.onEdit,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Expanded(
          child: Text(
            text,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: kaisei(
              size: 18,
              weight: FontWeight.w700,
              color: _bodyText,
            ).copyWith(height: 1.25),
          ),
        ),

        if (showEdit) ...[const SizedBox(width: 8), _EditButton(onTap: onEdit)],
      ],
    );
  }
}

// ============================================================
// 編輯按鈕
// ============================================================

class _EditButton extends StatefulWidget {
  final VoidCallback onTap;

  const _EditButton({required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  bool hovering = false;

  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.90
        : hovering
        ? 1.10
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

          duration: const Duration(milliseconds: 150),

          curve: Curves.easeOutBack,

          child: Image.asset(
            'img/edit.png',

            width: 31,
            height: 31,

            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Pin
// ============================================================

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 31,

      child: Stack(
        clipBehavior: Clip.none,

        children: [
          // ======================================================
          // Pin 本體
          // ======================================================
          Container(
            width: 21,
            height: 21,

            decoration: const BoxDecoration(
              shape: BoxShape.circle,

              gradient: RadialGradient(
                center: Alignment(-0.35, -0.4),

                radius: 0.9,

                colors: [
                  Color(0xFFE52F0E),
                  Color(0xFFB91F0C),
                  Color(0xFF7F1A08),
                ],

                stops: [0.0, 0.42, 1.0],
              ),

              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF7E1616), width: 1),
              ),

              boxShadow: [
                BoxShadow(
                  color: Color(0x80000000),
                  offset: Offset(2, 3),
                  blurRadius: 2,
                ),
              ],
            ),
          ),

          // ======================================================
          // Pin 高光
          // ======================================================
          Positioned(
            left: 5,
            top: 4,

            child: Container(
              width: 5,
              height: 4,

              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),

                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 登出按鈕
// ============================================================

class _LogoutButton extends StatefulWidget {
  final String text;

  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _LogoutButton({
    required this.text,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool hovering = false;

  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.05
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
            width: 275,
            height: 48,

            alignment: Alignment.center,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),

              border: Border.all(color: _buttonBorder, width: 2),

              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),

                radius: 1.15,

                colors: [_buttonCenter, _buttonCenter, _buttonOuter],

                stops: [0.0, 0.45, 1.0],
              ),

              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),

            child: Center(
              child: Text(
                widget.text,

                textAlign: TextAlign.center,

                style: widget
                    .kaisei(
                      size: 18,
                      weight: FontWeight.w800,
                      color: const Color(0xFFEBE1C7),
                    )
                    .copyWith(height: 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
