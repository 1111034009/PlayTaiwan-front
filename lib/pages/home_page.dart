import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';
import '../core/app_session.dart';
import '../api/nearby_cache.dart';
import 'selection_page.dart';
import 'collection_page.dart';
import 'past_page.dart';
import 'wallet_page.dart';
import 'love_story_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  String accountName = AppSession.epName ?? '';
  int completedStoryCount = 0;
  int postcardCount = 0;
  int badgeCount = 0;
  int vlogCount = 0;
  Future<void> _fetchProfile() async {
    final token = AppSession.token;
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/Auth/Profile'),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
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
      // print('Profile Error: $e');
    }
  }

  Future<void> _fetchOverview() async {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/Home/Overview'),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['isSuccess'] == true) {
          final result = data['Result'];

          if (result is Map<String, dynamic>) {
            if (!mounted) return;

            setState(() {
              completedStoryCount =
                  int.tryParse(
                    result['ho_completed_story']?.toString() ?? '0',
                  ) ??
                  0;

              postcardCount =
                  int.tryParse(
                    result['ho_postcard_count']?.toString() ?? '0',
                  ) ??
                  0;

              badgeCount =
                  int.tryParse(result['ho_badge_count']?.toString() ?? '0') ??
                  0;

              vlogCount =
                  int.tryParse(result['ho_vlog_count']?.toString() ?? '0') ?? 0;
            });
          }
        }
      }
    } catch (e) {
      // print('Overview Error: $e');
    }
  }

  void _showTopSnackBar(String message) {
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

  Future<bool> _updateProfile(String epName) async {
    final String newName = epName.trim();

    if (newName.isEmpty) {
      if (!mounted) return false;

      _showTopSnackBar('請探員輸入更改名稱');

      return false;
    }

    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      if (!mounted) return false;

      _showTopSnackBar('登入資訊已失效，請重新登入');

      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/Profile'),
        headers: {
          'accept': 'text/plain',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'auth_name': newName}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return false;

        setState(() {
          accountName = newName;
        });

        return true;
      }

      if (!mounted) return false;

      _showTopSnackBar('更新探員名稱失敗');

      return false;
    } catch (e) {
      if (!mounted) return false;

      _showTopSnackBar('無法連線到伺服器');

      return false;
    }
  }

  Future<bool> _changePassword(String oldPassword, String newPassword) async {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      if (!mounted) return false;

      _showTopSnackBar('登入資訊已失效，請重新登入');

      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/ChangePassword'),
        headers: {
          'accept': 'text/plain',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
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

      _showTopSnackBar('修改密碼失敗');

      return false;
    } catch (e) {
      if (!mounted) return false;

      _showTopSnackBar('無法連線到伺服器');

      return false;
    }
  }

  void _openWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalletPage()),
    );
  }

  void _openLoveStory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoveStoryPage()),
    );
  }

  static const Color pageColor = AppColors.background;
  static const Color darkText = AppColors.textPrimary;
  static const Color postcardColor = AppColors.postcard;
  static const Color postcardLine = AppColors.postcardLine;

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
    _fetchProfile();
    _fetchOverview();
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

          final double scale = AppResponsive.scale(
            availableWidth: constraints.maxWidth,
            availableHeight: constraints.maxHeight,
            designWidth: designWidth,
            designHeight: designHeight,
          );

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
                      Positioned.fill(child: Container(color: pageColor)),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _HomeDashedPainter()),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _ClueStringPainter()),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 54,
                        width: 210,
                        height: 170,
                        child: _OverviewCard(),
                      ),
                      Positioned(
                        left: 240,
                        top: 40,
                        width: 108,
                        height: 76,
                        child: _SimpleCard(
                          onTap: _openLoveStory,
                          child: _LoveStoryTicket(),
                        ),
                      ),
                      Positioned(
                        left: 214,
                        top: 161,
                        width: 128,
                        height: 92,
                        child: _SimpleCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CollectionPage(),
                              ),
                            );
                          },
                          child: _BadgeCard(),
                        ),
                      ),
                      Positioned(
                        left: 15,
                        top: 270,
                        width: 139,
                        height: 198,
                        child: _SimpleCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PastPage(),
                              ),
                            );
                          },
                          child: _TripPolaroid(),
                        ),
                      ),
                      Positioned(
                        left: 160,
                        top: 282,
                        width: 174,
                        height: 226,
                        child: _SimpleCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SelectionPage(),
                              ),
                            );
                          },
                          child: _GoPolaroid(),
                        ),
                      ),
                      Positioned(
                        left: 48,
                        top: 261,
                        width: 76,
                        height: 28,
                        child: _Tape(rotation: -0.015),
                      ),
                      Positioned(
                        left: 48,
                        top: 510,
                        width: 105,
                        height: 43,
                        child: _AgentInfo(onTap: _showAgentInfoDialog),
                      ),
                      Positioned(
                        left: 52,
                        top: 494,
                        width: 76,
                        height: 28,
                        child: _Tape(rotation: -0.025),
                      ),
                      Positioned(
                        left: 190,
                        top: 522,
                        width: 105,
                        height: 43,
                        child: _WalletButton(onTap: _openWallet),
                      ),
                      const Positioned(left: 116, top: 43, child: _PushPin()),
                      const Positioned(left: 283, top: 30, child: _PushPin()),
                      const Positioned(left: 320, top: 165, child: _PushPin()),
                      const Positioned(left: 264, top: 284, child: _PushPin()),
                      const Positioned(left: 232, top: 512, child: _PushPin()),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  void _showAgentInfoDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉探員資訊',
      barrierColor: AppColors.dialogBarrier,
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

  void _showEditAccountDialog() {
    final TextEditingController accountController = TextEditingController(
      text: accountName,
    );

    final TextEditingController oldPasswordController = TextEditingController();

    final TextEditingController newPasswordController = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '關閉編輯',
      barrierColor: AppColors.dialogBarrier,
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
            oldPasswordController: oldPasswordController,
            newPasswordController: newPasswordController,
            onSave: () async {
              final String newAccount = accountController.text.trim();
              final String oldPassword = oldPasswordController.text;
              final String newPassword = newPasswordController.text;

              if (newAccount.isEmpty) {
                _showTopSnackBar('帳號名稱不可為空');
                return;
              }
              final bool nameChanged = newAccount != accountName;
              final bool oldPasswordEntered = oldPassword.isNotEmpty;
              final bool newPasswordEntered = newPassword.isNotEmpty;
              if (oldPasswordEntered != newPasswordEntered) {
                _showTopSnackBar('原密碼與新密碼都必須填寫才可修改');
                return;
              }
              if (!nameChanged && !oldPasswordEntered && !newPasswordEntered) {
                Navigator.of(context).pop();
                return;
              }
              if (nameChanged) {
                final bool profileSuccess = await _updateProfile(newAccount);

                if (!profileSuccess) {
                  return;
                }
              }

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

  Future<void> _logout() async {
    final token = AppSession.token;
    NearbyCache.instance.stop();
    AppSession.clear();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/Logout'),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      if (!mounted) return;
      _showTopSnackBar('無法連線到伺服器');
    }
  }

  Widget _OverviewCard() {
    return Transform.rotate(
      angle: -0.012,
      child: Container(
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
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '目前總覽',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(
                      color: const Color(0xFF3D342E),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 17,
                right: 17,
                top: 45,
                child: Container(height: 1, color: const Color(0xFF51473F)),
              ),
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
                        style: AppTextStyles.captionBold.copyWith(
                          color: darkText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        completedStoryCount.toString(),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heroTitle.copyWith(
                          color: const Color(0xFF8C1D13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 94,
                width: 60,
                child: _OverviewNumber(
                  title: '明信片',
                  number: postcardCount.toString(),
                  titleColor: postcardLine,
                ),
              ),
              Positioned(
                left: 74,
                top: 94,
                width: 60,
                child: _OverviewNumber(
                  title: '徽章',
                  number: badgeCount.toString(),
                  titleColor: postcardLine,
                ),
              ),
              Positioned(
                left: 134,
                top: 94,
                width: 60,
                child: _OverviewNumber(
                  title: 'VLOG',
                  number: vlogCount.toString(),
                  titleColor: postcardLine,
                ),
              ),
            ],
          ),
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
          style: AppTextStyles.captionBold.copyWith(color: titleColor),
        ),
        const SizedBox(height: 2),
        Text(
          number,
          textAlign: TextAlign.center,
          style: AppTextStyles.display.copyWith(color: const Color(0xFF8C1D13)),
        ),
      ],
    );
  }

  Widget _BadgeCard() {
    return Transform.rotate(
      angle: 0.015,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
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
              left: 5,
              top: 20,
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
                    style: AppTextStyles.captionBold.copyWith(color: darkText),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _LoveStoryTicket() {
    return Transform.rotate(
      angle: -0.04,
      child: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x45000000),
              blurRadius: 5,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
            ),
            Positioned.fill(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 15,
                      color: Color(0xFF8C1D13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '喜愛劇本',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.captionBold.copyWith(
                        color: darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _Tape({double rotation = 0}) {
    return Transform.rotate(
      angle: rotation,
      child: Opacity(
        opacity: 0.88,
        child: Image.asset('img/tape.png', fit: BoxFit.fill),
      ),
    );
  }

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
                '過往遊玩',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmallBold.copyWith(color: darkText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _GoPolaroid() {
    return Transform.rotate(
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
                style: AppTextStyles.bodySmallBold.copyWith(color: darkText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _IconLabelButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
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
              Icon(icon, size: 20, color: darkText),
              const SizedBox(width: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.captionBold.copyWith(color: darkText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _AgentInfo({required VoidCallback onTap}) {
    return _IconLabelButton(icon: Icons.settings, label: '探員資訊', onTap: onTap);
  }

  Widget _WalletButton({required VoidCallback onTap}) {
    return _IconLabelButton(
      icon: Icons.account_balance_wallet_outlined,
      label: '錢包',
      onTap: onTap,
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SimpleCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

class _AgentInfoDialog extends StatelessWidget {
  final String accountName;
  final VoidCallback onEdit;
  final VoidCallback onLogout;

  const _AgentInfoDialog({
    required this.accountName,
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
            Positioned.fill(
              child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 22, 25, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '帳號名稱：$accountName',
                        style: AppTextStyles.subtitle.copyWith(
                          color: const Color(0xFF40342D),
                        ),
                      ),
                      const Spacer(),
                      _EditIconButton(onTap: onEdit),
                    ],
                  ),
                  const Spacer(),
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

class _EditAccountDialog extends StatelessWidget {
  final TextEditingController accountController;
  final TextEditingController oldPasswordController;
  final TextEditingController newPasswordController;
  final VoidCallback onSave;

  const _EditAccountDialog({
    required this.accountController,
    required this.oldPasswordController,
    required this.newPasswordController,
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
        height: 340,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
              child: Column(
                children: [
                  Text(
                    '編輯探員資料',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    controller: accountController,
                    label: '帳號名稱',
                    obscureText: false,
                  ),
                  const SizedBox(height: 12),
                  _EditField(
                    controller: oldPasswordController,
                    label: '原通行密碼',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _EditField(
                    controller: newPasswordController,
                    label: '新通行密碼',
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
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

class _EditIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: Image.asset(
            'img/edit.png',
            width: 27,
            height: 27,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

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
      style: AppTextStyles.bodyEmphasisBold.copyWith(
        color: AppColors.textPrimary,
      ),
      cursorColor: AppColors.primaryAccent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.captionBold.copyWith(
          color: const Color(0xFF6F6258),
        ),
        filled: true,
        fillColor: const Color(0x55FFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.postcardLine, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(
            color: AppColors.primaryAccent,
            width: 1.3,
          ),
        ),
      ),
    );
  }
}

class _PopupButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _PopupButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: AppColors.primaryAccent,
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
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.button.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StringLink {
  final Offset from;
  final Offset to;
  final double sag;

  const _StringLink(this.from, this.to, this.sag);
}

class _ClueStringPainter extends CustomPainter {
  static const List<_StringLink> _links = [
    _StringLink(Offset(127, 54), Offset(294, 41), 10),
    _StringLink(Offset(294, 41), Offset(331, 176), 6),
    _StringLink(Offset(331, 176), Offset(275, 295), 8),
    _StringLink(Offset(275, 295), Offset(86, 276), 18),
    _StringLink(Offset(243, 523), Offset(90, 508), 22),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint shadow = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

    final Paint string = Paint()
      ..color = AppColors.primaryAccent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint highlight = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final link in _links) {
      final Offset mid = Offset(
        (link.from.dx + link.to.dx) / 2,
        (link.from.dy + link.to.dy) / 2 + link.sag,
      );

      final Path path = Path()
        ..moveTo(link.from.dx, link.from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, link.to.dx, link.to.dy);

      canvas.save();
      canvas.translate(2, 3);
      canvas.drawPath(path, shadow);
      canvas.restore();

      canvas.drawPath(path, string);

      canvas.save();
      canvas.translate(-0.5, -0.5);
      canvas.drawPath(path, highlight);
      canvas.restore();
    }

    final Paint knot = Paint()..color = const Color(0xFF8D1D12);

    canvas.drawCircle(const Offset(86, 276), 2.6, knot);
    canvas.drawCircle(const Offset(90, 508), 2.6, knot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

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
