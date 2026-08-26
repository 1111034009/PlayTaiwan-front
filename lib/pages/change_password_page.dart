import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';

class ChangePasswordPage extends StatefulWidget {
  final String temporaryPassword;

  const ChangePasswordPage({super.key, required this.temporaryPassword});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool newPasswordObscure = true;
  bool confirmPasswordObscure = true;
  bool isLoading = false;

  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration({required String hintText}) {
    const border = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.inputLine, width: 1),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.inputHint),
      contentPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 0),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> changePassword() async {
    if (isLoading) {
      return;
    }

    final String newPassword = newPasswordController.text;
    final String confirmPassword = confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      showMessage('請完整填寫新密碼');
      return;
    }

    if (newPassword.length < 8) {
      showMessage('密碼至少需要8個字元');
      return;
    }

    if (newPassword.length > 40) {
      showMessage('密碼至多少於40個字元');
      return;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(newPassword)) {
      showMessage('密碼必須包含至少一個英文');
      return;
    }

    if (!RegExp(r'\d').hasMatch(newPassword)) {
      showMessage('密碼必須包含至少一個數字');
      return;
    }

    if (RegExp(r'[\u4E00-\u9FFF\s]').hasMatch(newPassword)) {
      showMessage('密碼不可包含中文或空白');
      return;
    }

    if (newPassword != confirmPassword) {
      showMessage('兩次密碼輸入不一致');
      return;
    }

    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      showMessage('登入資訊已失效，請重新登入');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/ChangePassword'),
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'OldPassword': widget.temporaryPassword,
          'NewPassword': newPassword,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        showMessage('密碼修改成功');

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;

          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        });
      } else {
        if (!mounted) return;

        showMessage('修改密碼失敗：HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('無法連線到伺服器');
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: designWidth,
                  height: designHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: AppColors.background),
                      ),
                      Positioned(
                        left: 13,
                        right: 13,
                        top: 145,
                        height: 380,
                        child: Image.asset(
                          'img/notepaper.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        top: 165,
                        child: Text(
                          '修改通行密碼',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        top: 195,
                        child: Text(
                          '設定你的新探險密碼',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmallBold.copyWith(
                            color: const Color(0xFF66615C),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 245,
                        child: _ChangePasswordField(
                          label: '新通行密碼',
                          child: _PasswordField(
                            controller: newPasswordController,
                            obscureText: newPasswordObscure,
                            hintText: '請輸入新密碼',
                            onToggle: () {
                              setState(() {
                                newPasswordObscure = !newPasswordObscure;
                              });
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 325,
                        child: _ChangePasswordField(
                          label: '確認通行密碼',
                          child: _PasswordField(
                            controller: confirmPasswordController,
                            obscureText: confirmPasswordObscure,
                            hintText: '再次輸入新密碼',
                            onToggle: () {
                              setState(() {
                                confirmPasswordObscure =
                                    !confirmPasswordObscure;
                              });
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 405,
                        child: Text(
                          '密碼需至少 8 個字元，並包含英文與數字',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF77716B),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 440,
                        child: Center(
                          child: SizedBox(
                            width: 140,
                            height: 49,
                            child: _ChangePasswordButton(
                              onPressed: changePassword,
                              isLoading: isLoading,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChangePasswordField extends StatelessWidget {
  final String label;
  final Widget child;

  const _ChangePasswordField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmallBold.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(height: 40, child: child),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final String hintText;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.obscureText,
    required this.hintText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            cursorColor: AppColors.primary,
            decoration: _inputDecoration(hintText: hintText),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 20,
                onPressed: onToggle,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    const border = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.inputLine, width: 1),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.inputHint),
      contentPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 0),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }
}

class _ChangePasswordButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _ChangePasswordButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  State<_ChangePasswordButton> createState() => _ChangePasswordButtonState();
}

class _ChangePasswordButtonState extends State<_ChangePasswordButton> {
  bool hovering = false;
  bool pressing = false;

  double get scale {
    if (pressing) return 0.96;
    if (hovering) return 1.08;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (widget.isLoading) return;

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
        onTap: widget.isLoading ? null : widget.onPressed,
        onTapDown: widget.isLoading
            ? null
            : (_) {
                setState(() {
                  pressing = true;
                });
              },
        onTapUp: widget.isLoading
            ? null
            : (_) {
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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            width: 140,
            height: 49,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.primaryDark, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x70000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '確認修改',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}
