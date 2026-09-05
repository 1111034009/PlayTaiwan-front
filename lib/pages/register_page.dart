import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

InputDecoration registerInputDecoration({required String hintText}) {
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;
  static final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  DateTime? birthday;
  String? gender;

  bool password = true;
  bool confirmPassword = true;
  bool isLoading = false;
  int accountType = 1;

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

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> selectBirthday() async {
    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '選擇生日',
      cancelText: '取消',
      confirmText: '確定',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.merchantPaper,
              onSurface: AppColors.textPrimary,
            ),
            textTheme: Theme.of(
              context,
            ).textTheme.apply(fontFamily: 'KaiseiHarunoUmi'),
          ),
          child: child!,
        );
      },
    );
    if (selectedDate == null) {
      return;
    }

    setState(() {
      birthday = selectedDate;
    });
  }

  String formatBirthday(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String getGenderForApi() {
    switch (gender) {
      case '男性':
        return 'Male';
      case '女性':
        return 'Female';
      case '其他':
        return 'Other';
      default:
        return '';
    }
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

    if (birthday == null) {
      showMessage('請選擇生日');
      return;
    }

    if (gender == null) {
      showMessage('請選擇性別');
      return;
    }

    if (username.length > 40) {
      showMessage('名稱至多少於40個字元');
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      showMessage('請輸入有效的 Email');
      return;
    }

    if (password.length < 8) {
      showMessage('密碼至少需要8個字元');
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

    if (accountType != 1 && accountType != 2) {
      showMessage('帳號類型無效');
      return;
    }
    final String genderForApi = getGenderForApi();

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/Register'),
        headers: {'accept': '*/*', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'Username': username,
          'Email': email,
          'Password': password,
          'Birthday': formatBirthday(birthday!),
          'Gender': genderForApi,
          'AccountType': accountType,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        showMessage('註冊成功！驗證信已發送至您的信箱，請先完成驗證再登入');

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          Navigator.pop(context);
        });
      } else {
        showMessage('註冊失敗');
      }
    } catch (e) {
      if (!mounted) return;

      showMessage('註冊時發生錯誤');
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
        child: Center(
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
                    top: 30,
                    height: 610,
                    child: Image.asset('img/notepaper.png', fit: BoxFit.fill),
                  ),
                  Positioned(
                    left: 23,
                    top: 5,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                    top: 60,
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
                    top: 90,
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
                    top: 120,
                    child: _RegisterField(
                      label: '探險名稱',
                      child: TextField(
                        controller: usernameController,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        cursorColor: AppColors.primary,
                        decoration: registerInputDecoration(
                          hintText: '請輸入探險名稱',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 42,
                    right: 42,
                    top: 190,
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
                        decoration: registerInputDecoration(
                          hintText: '請輸入 Email',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 42,
                    right: 42,
                    top: 260,
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
                    top: 330,
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
                    left: 42,
                    right: 42,
                    top: 400,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _RegisterField(
                            label: '生日',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: selectBirthday,
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.inputLine,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  birthday == null
                                      ? '請選擇生日'
                                      : formatBirthday(birthday!),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: birthday == null
                                        ? AppColors.inputHint
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _RegisterField(
                            label: '性別',
                            child: _GenderSelector(
                              value: gender,
                              onChanged: (value) {
                                setState(() {
                                  gender = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 42,
                    right: 42,
                    top: 470,
                    child: _RegisterField(
                      label: '帳號類型',
                      child: _AccountTypeSelector(
                        value: accountType,
                        onChanged: (value) {
                          setState(() {
                            accountType = value;
                          });
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 555,
                    child: Center(
                      child: SizedBox(
                        width: 240,
                        height: 45,
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

class _GenderSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const _GenderSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final String? selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: AppColors.merchantPaper,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      '男性',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, '男性'),
                  ),
                  ListTile(
                    title: Text(
                      '女性',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, '女性'),
                  ),
                  ListTile(
                    title: Text(
                      '其他',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, '其他'),
                  ),
                ],
              ),
            );
          },
        );

        if (selected != null) {
          onChanged(selected);
        }
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.inputLine, width: 1),
          ),
        ),
        child: Text(
          value ?? '請選擇性別',
          style: AppTextStyles.bodySmall.copyWith(
            color: value == null ? AppColors.inputHint : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AccountTypeSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _AccountTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AccountTypeButton(
            text: '遊客',
            selected: value == 1,
            onTap: () => onChanged(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AccountTypeButton(
            text: '商家',
            selected: value == 2,
            onTap: () => onChanged(2),
          ),
        ),
      ],
    );
  }
}

class _AccountTypeButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTypeButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? AppColors.darkBrown : Colors.transparent,
          border: Border.all(color: AppColors.darkBrown, width: 1.5),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySmallBold.copyWith(
            color: selected ? Colors.white : AppColors.darkBrown,
          ),
        ),
      ),
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
            decoration: registerInputDecoration(hintText: hintText),
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
            height: 45,
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
