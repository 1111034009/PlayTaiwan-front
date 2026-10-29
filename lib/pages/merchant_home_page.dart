import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_coupon_page.dart';
import 'merchant_file_item.dart';
import 'merchant_files_page.dart';
import 'merchant_info_page.dart';
import 'merchant_input_page.dart';
import 'merchant_task_page.dart';
import '../api/merchant_vlog_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';
import '../core/app_tutorial.dart';

const Color pageColor = AppColors.background;
const Color paperColor = AppColors.merchantPaper;
const Color paperBorder = Color(0xFF000000);
const Color darkText = AppColors.textPrimary;
const Color red = AppColors.primaryDark;
const Color generateRed = AppColors.primaryAccent;
const Color itemColor = AppColors.paper;

class MerchantHomePage extends StatefulWidget {
  const MerchantHomePage({super.key});

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  List<MerchantFile> files = [];
  bool isLoading = true;
  String? filesError;
  final GlobalKey _fileCardKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _videoKey = GlobalKey();
  final GlobalKey _manageKey = GlobalKey();
  final GlobalKey _recentKey = GlobalKey();
  List<MerchantFile> get recentFiles => files.take(8).toList();

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

    _fetchFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTutorial());
  }

  Future<void> _maybeStartTutorial() async {
    if (await AppTutorial.isDone(AppTutorial.merchantHomeId)) return;

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    AppTutorial.show(
      context,
      id: AppTutorial.merchantHomeId,
      steps: [
        TutorialStep(
          target: _fileCardKey,
          title: '已生成檔案',
          text: '這裡顯示你已生成的影音與檔案數量',
        ),
        TutorialStep(
          target: _settingsKey,
          title: '資訊設定',
          text: '修改店家資訊與帳號，也能調整背景音樂',
        ),
        TutorialStep(target: _videoKey, title: '前往生成影音', text: '用 AI 生成宣傳影片'),
        TutorialStep(
          target: _manageKey,
          title: '題庫與優惠券管理',
          text: '在這裡管理玩家的任務題庫和優惠券',
        ),
        TutorialStep(
          target: _recentKey,
          title: '最近檔案',
          text: '最近生成的檔案都在這裡，點開可以查看',
          align: ContentAlign.top,
        ),
      ],
    );
  }

  Future<void> _fetchFiles({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        isLoading = true;
        filesError = null;
      });
    }

    try {
      final loadedFiles = await MerchantVlogApi.fetchFiles();

      if (!mounted) return;

      setState(() {
        files = loadedFiles;
        isLoading = false;
        filesError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        filesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void openSettings() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromARGB(199, 0, 0, 0),
      builder: (_) => const MerchantInfoPage(),
    );
  }

  void openVideoGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantInputPage()),
    );
  }

  void openTaskManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantTaskPage()),
    );
  }

  void openCouponManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantCouponPage()),
    );
  }

  Future<void> openAllFiles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantFilesPage()),
    );

    if (mounted) _fetchFiles(silent: true);
  }

  Future<void> openFile(MerchantFile file) async {
    await openMerchantFile(context, file);

    if (mounted) _fetchFiles(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = AppResponsive.scale(
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
                      const Positioned.fill(
                        child: ColoredBox(color: pageColor),
                      ),
                      Positioned(
                        left: 23,
                        top: 58,
                        width: 198,
                        height: 118,
                        child: KeyedSubtree(
                          key: _fileCardKey,
                          child: _GeneratedFileCard(
                            count: files.length,
                            isLoading: isLoading,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 224,
                        top: 60,
                        width: 110,
                        height: 40,
                        child: KeyedSubtree(
                          key: _settingsKey,
                          child: _SmallActionButton(
                            icon: Icons.settings,
                            text: '資訊設定',
                            onTap: openSettings,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 224,
                        top: 106,
                        width: 110,
                        height: 66,
                        child: KeyedSubtree(
                          key: _videoKey,
                          child: _GenerateVideoButton(
                            text: '前往生成影音',
                            onTap: openVideoGenerator,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 187,
                        width: 311,
                        height: 53,
                        child: KeyedSubtree(
                          key: _manageKey,
                          child: _ManagementButtons(
                            onTaskTap: openTaskManagement,
                            onCouponTap: openCouponManagement,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 253,
                        width: 311,
                        height: 253,
                        child: KeyedSubtree(
                          key: _recentKey,
                          child: _RecentFilesCard(
                            files: recentFiles,
                            isLoading: isLoading,
                            error: filesError,
                            onOpen: openFile,
                            onMore: openAllFiles,
                            onRetry: _fetchFiles,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final double size;

  const _Pin({this.size = 19});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 5,
      height: size + 7,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.dangerDark, width: 1),
                gradient: const RadialGradient(
                  center: Alignment(-0.35, -0.4),
                  radius: 0.9,
                  colors: [
                    Color(0xFFE52F0E),
                    Color(0xFFB91F0C),
                    AppColors.deepRed,
                  ],
                  stops: [0.0, 0.42, 1.0],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    offset: Offset(2, 4),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: size * 0.22,
            top: size * 0.18,
            child: Container(
              width: size * 0.27,
              height: size * 0.20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFA18D), Color(0x00EFA18D)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedFileCard extends StatelessWidget {
  final int count;
  final bool isLoading;

  const _GeneratedFileCard({required this.count, required this.isLoading});

  static const double cardWidth = 190;
  static const double cardHeight = 118;
  static const double tapeWidth = 80;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.black, width: 1.2),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    '目前已生成檔案',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionTitle.copyWith(color: darkText),
                  ),
                  const SizedBox(height: 6),
                  Container(width: 105, height: 1, color: darkText),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: red,
                              ),
                            )
                          : Text(
                              '$count',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.merchantStat
                                  .copyWith(color: red)
                                  .copyWith(height: 1),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: (cardWidth - tapeWidth) / 2,
          width: tapeWidth,
          top: -9,
          height: 19,
          child: Image.asset('img/tape.png', fit: BoxFit.fill),
        ),
      ],
    );
  }
}

class _ManagementButtons extends StatelessWidget {
  final VoidCallback onTaskTap;
  final VoidCallback onCouponTap;

  const _ManagementButtons({
    required this.onTaskTap,
    required this.onCouponTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ManagementButton(
            icon: Icons.assignment_outlined,
            title: '題庫管理',
            onTap: onTaskTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ManagementButton(
            icon: Icons.confirmation_number_outlined,
            title: '優惠券管理',
            onTap: onCouponTap,
          ),
        ),
      ],
    );
  }
}

class _ManagementButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ManagementButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_ManagementButton> createState() => _ManagementButtonState();
}

class _ManagementButtonState extends State<_ManagementButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: paperColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.black, width: 1.2),
            boxShadow: const [
              BoxShadow(color: darkText, offset: Offset(2, 3), blurRadius: 0),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: generateRed.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: darkText, width: 1),
                ),
                child: Icon(widget.icon, size: 20, color: red),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: darkText,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: darkText.withOpacity(0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatefulWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  State<_SmallActionButton> createState() => _SmallActionButtonState();
}

class _SmallActionButtonState extends State<_SmallActionButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => pressing = true),
          onTapUp: (_) => setState(() => pressing = false),
          onTapCancel: () => setState(() => pressing = false),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: darkText,
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 24, color: darkText),
                  const SizedBox(width: 5),
                  Text(
                    widget.text,
                    style: AppTextStyles.captionBold.copyWith(color: darkText),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(right: -2, top: -9, child: _Pin(size: 18)),
      ],
    );
  }
}

class _GenerateVideoButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _GenerateVideoButton({required this.text, required this.onTap});

  @override
  State<_GenerateVideoButton> createState() => _GenerateVideoButtonState();
}

class _GenerateVideoButtonState extends State<_GenerateVideoButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: generateRed,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: darkText,
                blurRadius: 0,
                spreadRadius: 0,
                offset: Offset(3, 4),
              ),
            ],
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold
                .copyWith(color: paperColor)
                .copyWith(height: 1.25),
          ),
        ),
      ),
    );
  }
}

class _RecentFilesCard extends StatelessWidget {
  static const double itemGap = 5;

  final List<MerchantFile> files;
  final bool isLoading;
  final String? error;
  final ValueChanged<MerchantFile> onOpen;
  final VoidCallback onMore;
  final VoidCallback onRetry;

  const _RecentFilesCard({
    required this.files,
    required this.isLoading,
    required this.error,
    required this.onOpen,
    required this.onMore,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: paperColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.black, width: 1.2),
            boxShadow: const [
              BoxShadow(color: darkText, blurRadius: 0, offset: Offset(1, 2)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '近期檔案',
                    style: AppTextStyles.titleMediumBold.copyWith(
                      color: darkText,
                    ),
                  ),
                  const Spacer(),
                  if (files.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onMore,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '查看更多 >',
                          style: AppTextStyles.captionBold.copyWith(
                            color: red,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildFileContent()),
            ],
          ),
        ),
        const Positioned(left: 1, top: -1, child: _Pin(size: 19)),
      ],
    );
  }

  Widget _buildFileContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: red),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.captionBold.copyWith(color: darkText),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                '重新載入',
                style: AppTextStyles.captionBold.copyWith(
                  color: red,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (files.isEmpty) {
      return Center(
        child: Text(
          '目前沒有生成檔案',
          style: AppTextStyles.captionBold.copyWith(color: darkText),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: files.length,
      separatorBuilder: (_, __) => const SizedBox(height: itemGap),
      itemBuilder: (context, index) {
        final file = files[index];

        return MerchantFileItem(file: file, onTap: () => onOpen(file));
      },
    );
  }
}
