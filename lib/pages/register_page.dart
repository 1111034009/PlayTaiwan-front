import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool password = true;
  bool confirmPassword = true;
  bool isLoading = false;
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
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
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

  Future<void> register() async {
    if (isLoading) {
      return;
    }
    final String username = usernameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String confirmPassword = confirmPasswordController.text;
    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage('請完整填寫註冊資料');
      return;
    }
    if (password.length < 8) {
      showMessage('密碼至少需要8個字元');
      return;
    }
    if (username.length > 40) {
      showMessage('名稱至多少於40個字元');
      return;
    }
    if (password.length > 40) {
      showMessage('密碼至多少於40個字元');
      return;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      showMessage('密碼必須包含至少一個英文');
      return;
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      showMessage('密碼必須包含至少一個數字');
      return;
    }

    if (RegExp(r'[\u4E00-\u9FFF\s]').hasMatch(password)) {
      showMessage('密碼不可包含中文或空白');
      return;
    }
    if (password != confirmPassword) {
      showMessage('兩次密碼輸入不一致');
      return;
    }
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5501/api/Auth/Register'),
        headers: {'accept': '*/*', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'Username': username,
          'Email': email,
          'Password': password,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        showMessage('註冊成功！驗證信已發送至您的信箱，請先完成驗證再登入');

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;

          Navigator.pop(context);
        });
      } else {
        showMessage('註冊失敗：HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Register Error: $e');

      if (!mounted) return;

      showMessage('無法連線到伺服器');
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  void goBack() {
    Navigator.pop(context);
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
                        height: 460,
                        child: Image.asset(
                          'img/notepaper.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned(
                        left: 23,
                        top: 28,
                        child: GestureDetector(
                          onTap: goBack,
                          child: Text(
                            '<< 返回',
                            style: AppTextStyles.bodySmallBold.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        top: 165,
                        child: Text(
                          '建立探險帳號',
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
                          '建立你的專屬探險身份',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmallBold.copyWith(
                            color: const Color(0xFF66615C),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 235,
                        child: _RegisterField(
                          label: '探險名稱',
                          child: TextField(
                            controller: usernameController,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            cursorColor: AppColors.primary,
                            decoration: inputDecoration(hintText: '請輸入探險名稱'),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 305,
                        child: _RegisterField(
                          label: '電子信箱',
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            cursorColor: AppColors.primary,
                            decoration: inputDecoration(hintText: '請輸入 Email'),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 375,
                        child: _RegisterField(
                          label: '通行密碼',
                          child: _PasswordField(
                            controller: passwordController,
                            obscureText: password,
                            hintText: '請輸入密碼',
                            onToggle: () {
                              setState(() {
                                password = !password;
                              });
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        left: 42,
                        right: 42,
                        top: 445,
                        child: _RegisterField(
                          label: '確認密碼',
                          child: _PasswordField(
                            controller: confirmPasswordController,
                            obscureText: confirmPassword,
                            hintText: '再次輸入密碼',
                            onToggle: () {
                              setState(() {
                                confirmPassword = !confirmPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 525,
                        child: Center(
                          child: SizedBox(
                            width: 120,
                            height: 49,
                            child: _RegisterButton(
                              onPressed: register,
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

class _RegisterField extends StatelessWidget {
  final String label;
  final Widget child;

  const _RegisterField({required this.label, required this.child});

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
            decoration: inputDecorationWithoutIcon(hintText: hintText),
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

  InputDecoration inputDecorationWithoutIcon({required String hintText}) {
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

class _RegisterButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _RegisterButton({required this.onPressed, required this.isLoading});

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton> {
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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            width: 120,
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
                    '註冊',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}
