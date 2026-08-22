import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'merchant_info_page.dart';
import 'merchant_input_page.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';

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

  final List<_MerchantFile> recentFiles = const [
    _MerchantFile(title: '日式復古串燒居酒屋', date: '2026.08.01'),
    _MerchantFile(title: '巷弄咖啡廳-暑期活動', date: '2026.08.01'),
    _MerchantFile(title: '巷弄咖啡廳-暑期活動', date: '2026.08.01'),
  ];

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
  void openSettings() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromARGB(199, 0, 0, 0),
      builder: (_) {
        return const MerchantInfoPage();
      },
    );
  }

  void openVideoGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantInputPage()),
    );
  }

  void playFile(_MerchantFile file) {
    _showMessage('播放：${file.title}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: paperColor),
          ),
          backgroundColor: red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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
                        top: 78,
                        width: 198,
                        height: 118,
                        child: _GeneratedFileCard(),
                      ),
                      Positioned(
                        left: 224,
                        top: 80,
                        width: 110,
                        height: 40,
                        child: _SmallActionButton(
                          icon: Icons.settings,
                          text: '資訊設定',
                          onTap: openSettings,
),
                      ),
                      Positioned(
                        left: 224,
                        top: 126,
                        width: 110,
                        height: 66,
                        child: _GenerateVideoButton(
                          text: '前往生成影音',
                          onTap: openVideoGenerator,
),
                      ),
                      Positioned(
                        left: 24,
                        top: 212,
                        width: 311,
                        height: 294,
                        child: _RecentFilesCard(
                          files: recentFiles,
                          onPlay: playFile,
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
const _GeneratedFileCard();

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
                  Text(
                    '25',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.merchantStat.copyWith(color: red).copyWith(height: 1),
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
  const _GenerateVideoButton({
    required this.text,
    required this.onTap,
});

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
              style: AppTextStyles.bodySmallBold.copyWith(color: paperColor)
                  .copyWith(height: 1.25),
            ),
          ),
        ),
      );
  }
}

class _RecentFilesCard extends StatelessWidget {
  final List<_MerchantFile> files;
  final ValueChanged<_MerchantFile> onPlay;
  const _RecentFilesCard({
    required this.files,
    required this.onPlay,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '近期檔案',
                style: AppTextStyles.titleMediumBold.copyWith(color: darkText),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < files.length; i++) ...[
                      Expanded(
                        child: _RecentFileItem(
                          file: files[i],
                          onPlay: () => onPlay(files[i]),
),
                      ),
                      if (i != files.length - 1) const SizedBox(height: 9),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(left: 1, top: -1, child: _Pin(size: 19)),
      ],
    );
  }
}

class _RecentFileItem extends StatefulWidget {
  final _MerchantFile file;
  final VoidCallback onPlay;
  const _RecentFileItem({
    required this.file,
    required this.onPlay,
});

  @override
  State<_RecentFileItem> createState() => _RecentFileItemState();
}

class _RecentFileItemState extends State<_RecentFileItem> {
bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.98 : 1;

    return GestureDetector(
        onTap: widget.onPlay,
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: itemColor,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: darkText, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C807A),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.file.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.captionBold.copyWith(color: Colors.black)
                            .copyWith(height: 1.15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.file.date,
                        style: AppTextStyles.captionBold.copyWith(color: Colors.black.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                _PlayButton(onTap: widget.onPlay),
              ],
            ),
          ),
        ),
      );
  }
}

class _PlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.90 : 1;

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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: red,
              border: Border.all(color: darkText, width: 1.2),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 19,
              color: paperColor,
            ),
          ),
        ),
      );
  }
}

class _MerchantFile {
  final String title;
  final String date;

  const _MerchantFile({required this.title, required this.date});
}
