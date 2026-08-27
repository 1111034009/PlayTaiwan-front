import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';

const Color _pageColor = AppColors.background;
const Color _paperColor = AppColors.card;
const Color _paperBorder = Color(0xFF000000);
const Color _darkText = AppColors.textPrimary;
const Color _bodyText = Color(0xFF2F2D28);

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

const Color _accentRed = AppColors.deepRed;

class MerchantInfoPage extends StatefulWidget {
  const MerchantInfoPage({super.key});

  @override
  State<MerchantInfoPage> createState() => _MerchantInfoPageState();
}

class _MerchantInfoPageState extends State<MerchantInfoPage> {
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  // 從 AppSession 取得目前登入的帳號名稱
  String accountName = AppSession.epName ?? '';

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

    _fetchProfile();
  }

  /// 取得目前登入帳號資訊
  Future<void> _fetchProfile() async {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/Auth/Profile'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['isSuccess'] == true) {
          final result = data['Result'];

          final String? epName = result?['ep_name']?.toString();

          if (epName != null && epName.isNotEmpty) {
            if (!mounted) return;

            setState(() {
              accountName = epName;
            });
          }
        }
      }
    } catch (e) {
      // 需要的話可以在這裡處理錯誤
    }
  }

  /// 修改帳號名稱
  Future<bool> _updateProfile(String epName) async {
    final String newName = epName.trim();

    if (newName.isEmpty) {
      if (!mounted) return false;

      _showSnackBar('帳號名稱不可為空');
      return false;
    }

    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      if (!mounted) return false;

      _showSnackBar('登入資訊已失效，請重新登入');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/Profile'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ep_name': newName}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return false;

        setState(() {
          accountName = newName;
        });

        // 如果 AppSession 有提供 epName setter，
        // 建議同步更新 Session。
        //
        // 例如：
        // AppSession.epName = newName;

        return true;
      }

      if (!mounted) return false;

      _showSnackBar('更新帳號名稱失敗');
      return false;
    } catch (e) {
      if (!mounted) return false;

      _showSnackBar('無法連線到伺服器');
      return false;
    }
  }

  /// 修改密碼
  Future<bool> _changePassword(String oldPassword, String newPassword) async {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      if (!mounted) return false;

      _showSnackBar('登入資訊已失效，請重新登入');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/ChangePassword'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'OldPassword': oldPassword,
          'NewPassword': newPassword,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      if (!mounted) return false;

      _showSnackBar('修改密碼失敗');
      return false;
    } catch (e) {
      if (!mounted) return false;

      _showSnackBar('無法連線到伺服器');
      return false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    final OverlayState overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: 20,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: _TopSnackBar(
                  message: message,
                  onClose: () {
                    if (overlayEntry.mounted) {
                      overlayEntry.remove();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> editAccount() async {
    final result = await showDialog<_AccountEditResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xDD000000),
      builder: (dialogContext) {
        return _AccountEditDialog(initialAccountName: accountName);
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final String newAccountName = result.accountName.trim();
    final String oldPassword = result.oldPassword;
    final String newPassword = result.newPassword;

    if (newAccountName.isEmpty) {
      _showSnackBar('帳號名稱不可為空');
      return;
    }

    final bool nameChanged = newAccountName != accountName;

    final bool oldPasswordEntered = oldPassword.isNotEmpty;
    final bool newPasswordEntered = newPassword.isNotEmpty;

    // 密碼必須兩個一起填
    if (oldPasswordEntered != newPasswordEntered) {
      _showSnackBar('原密碼與新密碼都必須填寫才可修改');
      return;
    }

    // 完全沒有修改
    if (!nameChanged && !oldPasswordEntered && !newPasswordEntered) {
      return;
    }

    // 修改名稱
    if (nameChanged) {
      final bool profileSuccess = await _updateProfile(newAccountName);

      if (!profileSuccess) {
        return;
      }
    }

    // 修改密碼
    if (oldPasswordEntered && newPasswordEntered) {
      final bool passwordSuccess = await _changePassword(
        oldPassword,
        newPassword,
      );

      if (!passwordSuccess) {
        return;
      }
    }

    if (!mounted) return;

    _showSnackBar('探員資料更新成功');
  }

  void editShop() {
    _showEditShopDialog();
  }

  Future<void> _showEditShopDialog() async {
    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xDD000000),
      builder: (dialogContext) {
        return _EditDialog(
          title: '編輯店家名稱',
          label: '店家名稱',
          initialValue: shopName,
        );
      },
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

  Future<void> logout() async {
    final token = AppSession.token;

    // 先清除本地 Session
    AppSession.clear();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/Logout'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      // 已經導向登入頁，不需要再處理 UI
    }
  }

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
            onEditAccount: editAccount,
            onEditShop: editShop,
            onLogout: logout,
          ),
        ),
      ),
    );
  }
}

/// 帳號編輯結果
class _AccountEditResult {
  final String accountName;
  final String oldPassword;
  final String newPassword;

  const _AccountEditResult({
    required this.accountName,
    required this.oldPassword,
    required this.newPassword,
  });
}

/// 帳號名稱 + 密碼編輯 Dialog
class _AccountEditDialog extends StatefulWidget {
  final String initialAccountName;

  const _AccountEditDialog({required this.initialAccountName});

  @override
  State<_AccountEditDialog> createState() => _AccountEditDialogState();
}

class _AccountEditDialogState extends State<_AccountEditDialog> {
  late final TextEditingController accountController;
  late final TextEditingController oldPasswordController;
  late final TextEditingController newPasswordController;

  @override
  void initState() {
    super.initState();

    accountController = TextEditingController(text: widget.initialAccountName);

    oldPasswordController = TextEditingController();

    newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    accountController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();

    super.dispose();
  }

  void submit() {
    final String accountName = accountController.text.trim();
    final String oldPassword = oldPasswordController.text;
    final String newPassword = newPasswordController.text;

    if (accountName.isEmpty) {
      return;
    }

    Navigator.pop(
      context,
      _AccountEditResult(
        accountName: accountName,
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '編輯探員資料',
                style: AppTextStyles.titleLarge
                    .copyWith(color: Colors.black)
                    .copyWith(height: 1.0),
              ),

              const SizedBox(height: 18),

              _AccountTextField(
                controller: accountController,
                label: '帳號名稱',
                obscureText: false,
              ),

              const SizedBox(height: 12),

              _AccountTextField(
                controller: oldPasswordController,
                label: '原通行密碼',
                obscureText: true,
              ),

              const SizedBox(height: 12),

              _AccountTextField(
                controller: newPasswordController,
                label: '新通行密碼',
                obscureText: true,
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      '取消',
                      style: AppTextStyles.bodyEmphasisBold.copyWith(
                        color: _bodyText,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

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
                    onPressed: submit,
                    child: Text(
                      '儲存',
                      style: AppTextStyles.bodyEmphasisBold.copyWith(
                        color: _paperColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;

  const _AccountTextField({
    required this.controller,
    required this.label,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLength: 30,
      textAlign: TextAlign.center,
      style: AppTextStyles.subtitle.copyWith(color: _bodyText),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: AppTextStyles.captionBold.copyWith(
          color: const Color(0xFF6F6258),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: _accentRed, width: 2),
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;

  const _EditDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController controller;
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();

    controller = TextEditingController(text: widget.initialValue);

    focusNode = FocusNode();
  }

  @override
  void dispose() {
    focusNode.dispose();
    controller.dispose();

    super.dispose();
  }

  void submit() {
    final String value = controller.text.trim();

    if (value.isEmpty) {
      return;
    }

    focusNode.unfocus();

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: AppTextStyles.titleLarge
                    .copyWith(color: Colors.black)
                    .copyWith(height: 1.0),
              ),

              const SizedBox(height: 18),

              Text(
                widget.label,
                style: AppTextStyles.bodyEmphasisBold.copyWith(
                  color: _bodyText,
                ),
              ),

              const SizedBox(height: 7),

              TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                maxLength: 30,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.subtitle.copyWith(color: _bodyText),
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
                onSubmitted: (_) => submit(),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      focusNode.unfocus();
                      Navigator.pop(context);
                    },
                    child: Text(
                      '取消',
                      style: AppTextStyles.bodyEmphasisBold.copyWith(
                        color: _bodyText,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

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
                    onPressed: submit,
                    child: Text(
                      '儲存',
                      style: AppTextStyles.bodyEmphasisBold.copyWith(
                        color: _paperColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String accountName;
  final String shopName;
  final VoidCallback onEditAccount;
  final VoidCallback onEditShop;
  final VoidCallback onLogout;

  const _InfoCard({
    required this.accountName,
    required this.shopName,
    required this.onEditAccount,
    required this.onEditShop,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
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
              _SectionTitle(icon: 'img/user_icon.png', title: '帳號資訊'),

              const SizedBox(height: 14),

              _InfoRow(
                text: '帳號名稱：$accountName',
                showEdit: true,
                onEdit: onEditAccount,
              ),

              const SizedBox(height: 20),

              _SectionTitle(icon: 'img/shop_icon.png', title: '預設資訊'),

              const SizedBox(height: 14),

              _InfoRow(text: '店家名稱：', showEdit: false, onEdit: onEditShop),

              const SizedBox(height: 3),

              _InfoRow(text: shopName, showEdit: true, onEdit: onEditShop),

              const SizedBox(height: 12),

              Text(
                '輸出格式：9:16',
                style: AppTextStyles.sectionTitle
                    .copyWith(color: _bodyText)
                    .copyWith(height: 1.15),
              ),

              const Spacer(),

              Center(
                child: _LogoutButton(text: '登出', onTap: onLogout),
              ),
            ],
          ),
        ),

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

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(icon, width: 27, height: 27, fit: BoxFit.contain),

        const SizedBox(width: 7),

        Text(
          title,
          style: AppTextStyles.pageTitle
              .copyWith(color: Colors.black)
              .copyWith(height: 1.0),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  final bool showEdit;
  final VoidCallback onEdit;

  const _InfoRow({
    required this.text,
    required this.showEdit,
    required this.onEdit,
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
            style: AppTextStyles.sectionTitle
                .copyWith(color: _bodyText)
                .copyWith(height: 1.25),
          ),
        ),

        if (showEdit) ...[const SizedBox(width: 8), _EditButton(onTap: onEdit)],
      ],
    );
  }
}

class _EditButton extends StatefulWidget {
  final VoidCallback onTap;

  const _EditButton({required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.90 : 1.0;

    return GestureDetector(
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
    );
  }
}

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
                  AppColors.deepRed,
                ],
                stops: [0.0, 0.42, 1.0],
              ),
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.dangerDark, width: 1),
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

class _LogoutButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _LogoutButton({required this.text, required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1.0;

    return GestureDetector(
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
              style: AppTextStyles.sectionTitle
                  .copyWith(color: AppColors.paper)
                  .copyWith(height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSnackBar extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _TopSnackBar({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF40342D),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
