import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoading = false;

  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  static const Color pageColor = AppColors.background;
  static const Color darkText = AppColors.textPrimary;
  static const Color lineColor = AppColors.inputLine;
  static const Color cursorColor = AppColors.primary;
  static const Color hintColor = AppColors.inputHint;

  static const double designWidth = 360;
  static const double designHeight = 640;

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

  Future<void> login() async {
    final String account = accountController.text.trim();
    final String password = passwordController.text;

    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入帳號與密碼')));
      return;
    }

    if (isLoading) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

      if (baseUrl.isEmpty) {
        throw Exception('API_BASE_URL 未設定');
      }

      final String normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final Uri uri = Uri.parse('$normalizedBaseUrl/api/Auth/Login');

      final response = await http.post(
        uri,
        headers: {'accept': '*/*', 'Content-Type': 'application/json'},
        body: jsonEncode({'ep_name': account, 'ep_pswd': password}),
      );

      Map<String, dynamic>? data;

      try {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        data = null;
      }

      final bool isSuccess = data?['isSuccess'] == true;
      final String message = data?['message']?.toString() ?? '登入失敗';

      if (isSuccess) {
        final dynamic rawResult = data?['Result'];

        if (rawResult is! Map<String, dynamic>) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('權限失敗')));

          return;
        }

        final String? token = rawResult['token']?.toString();
        final String? epId = rawResult['ep_id']?.toString();
        final String? epName = rawResult['ep_name']?.toString();

        if (token == null || token.isEmpty) {
          if (!mounted) return;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('權限失敗')));

          return;
        }

        AppSession.token = token;
        AppSession.epId = epId;
        AppSession.epName = epName;

        if (!mounted) return;

        Navigator.pushReplacementNamed(context, '/user-type');
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請探員確認連線~')));
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  InputDecoration inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodySmall.copyWith(color: hintColor),
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
          Text(
            title,
            style: AppTextStyles.bodyEmphasisBold.copyWith(color: darkText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
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
                Positioned.fill(child: Container(color: pageColor)),

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

                Positioned(
                  left: 13,
                  right: 13,
                  top: 184,
                  height: 420,
                  child: Image.asset('img/notepaper.png', fit: BoxFit.fill),
                ),

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

                Positioned(
                  top: 263,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Text(
                      '日遊所思，夜遊所夢',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: const Color(0xFF292522),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 292,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Text(
                      'Play Taiwan',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmallBold.copyWith(
                        color: const Color(0xFF66615C),
                      ),
                    ),
                  ),
                ),

                sectionTitle(icon: 'img/user.png', title: '探險代號', top: 325),

                Positioned(
                  left: 46,
                  right: 46,
                  top: 356,
                  height: 40,
                  child: TextField(
                    controller: accountController,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    style: AppTextStyles.bodySmall.copyWith(color: darkText),
                    cursorColor: cursorColor,
                    decoration: inputDecoration(hintText: '請輸入帳號'),
                  ),
                ),

                sectionTitle(icon: 'img/password.png', title: '通行密碼', top: 412),

                Positioned(
                  left: 46,
                  right: 46,
                  top: 443,
                  height: 40,
                  child: TextField(
                    controller: passwordController,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    style: AppTextStyles.bodySmall.copyWith(color: darkText),
                    cursorColor: cursorColor,
                    onSubmitted: (_) => login(),
                    decoration: inputDecoration(hintText: '請輸入密碼'),
                  ),
                ),

                Positioned(
                  top: 506,
                  left: 0,
                  right: 0,
                  height: 49,
                  child: Center(
                    child: SizedBox(
                      width: 90,
                      height: 49,
                      child: _LoginButton(
                        onPressed: login,
                        isLoading: isLoading,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 560,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _RegisterLink(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
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

class _LoginButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _LoginButton({required this.onPressed, required this.isLoading});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool isPressing = false;

  void _setPressing(bool value) {
    if (!mounted || isPressing == value) {
      return;
    }

    setState(() {
      isPressing = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.isLoading ? null : widget.onPressed,
      onTapDown: widget.isLoading
          ? null
          : (_) {
              _setPressing(true);
            },
      onTapUp: widget.isLoading
          ? null
          : (_) {
              _setPressing(false);
            },
      onTapCancel: widget.isLoading
          ? null
          : () {
              _setPressing(false);
            },
      child: AnimatedScale(
        scale: isPressing ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          width: 90,
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
                  '登入',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}

class _RegisterLink extends StatelessWidget {
  final VoidCallback onTap;

  const _RegisterLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '還沒帳號？',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(
              text: '前往註冊',
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
