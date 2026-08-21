import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:google_fonts/google_fonts.dart';

import '../block/navigationbar.dart';
import 'past_page.dart';
import '../core/app_colors.dart';
import 'past_media_page.dart';

const Color _pageColor = Color(0xFF4F4141);

const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;

const Color _sectionRed = AppColors.primaryAccent;

const Color _photoColor = AppColors.postcard;
const Color _photoBorder = AppColors.postcardLine;

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

class PastDetailPage extends StatefulWidget {
  final String title;
  final String completedDate;

  const PastDetailPage({
    super.key,
    this.title = '府城儒生失落卷',
    this.completedDate = '2026.08.09',
  });

  @override
  State<PastDetailPage> createState() => _PastDetailPageState();
}

class _PastDetailPageState extends State<PastDetailPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;
  static const double contentScale = 1.06;

  int currentIndex = 3;

  static const List<String> photoAssets = [
    'img/home_trip.png',
    'img/home_gogo.png',
    'img/home_trip.png',
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  TextStyle kaisei({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = _darkBrown,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  void backToPast() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PastPage()),
    );
  }

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: kaisei(
              size: 12,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: _darkText,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void onNavigationTap(int index) {
    setState(() {
      currentIndex = index;
    });

    if (index == 3) {
      return;
    }

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/story-map');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/collection');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Center(
        child: Transform.translate(
          offset: const Offset(0, -20),
          child: Transform.scale(
            scale: contentScale,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(child: ColoredBox(color: _pageColor)),
                    Positioned(
                      left: 22,
                      top: 49,
                      child: _BackButton(onTap: backToPast, kaisei: kaisei),
                    ),
                    Positioned(
                      left: 16,
                      top: 78,
                      width: 328,
                      height: 504,
                      child: Image.asset(
                        'img/long_papper.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned(
                      left: 35,
                      right: 35,
                      top: 105,
                      bottom: 67,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kaisei(
                              size: 20,
                              weight: FontWeight.w900,
                              color: _darkText,
                            ),
                          ),
                          Text(
                            '完成日期：${widget.completedDate}',
                            style: kaisei(
                              size: 12,
                              weight: FontWeight.w700,
                              color: _sectionRed,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 128,
                            child: FlutterCarousel(
                              options: FlutterCarouselOptions(
                                height: 128,
                                viewportFraction: 0.68,
                                initialPage: 1,
                                enableInfiniteScroll: true,
                                autoPlay: false,
                                enlargeCenterPage: true,
                                showIndicator: false,
                                pageSnapping: true,
                                scrollDirection: Axis.horizontal,
                                enlargeStrategy:
                                    CenterPageEnlargeStrategy.scale,
                              ),
                              items: photoAssets.map((asset) {
                                return _PastPhoto(
                                  assetPath: asset,
                                  kaisei: kaisei,
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '探索總覽',
                            style: kaisei(
                              size: 16,
                              weight: FontWeight.w900,
                              color: _sectionRed,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _ChapterItem(
                            number: '第一站',
                            title: '臺南孔廟',
                            kaisei: kaisei,
                          ),
                          _ChapterItem(
                            number: '第二站',
                            title: '國立臺灣文學館',
                            kaisei: kaisei,
                          ),
                          _ChapterItem(
                            number: '第三站',
                            title: '林百貨',
                            kaisei: kaisei,
                          ),
                          _ChapterItem(
                            number: '第四站',
                            title: '神農街',
                            kaisei: kaisei,
                          ),
                          _ChapterItem(
                            number: '第五站',
                            title: '臺南孔武廟',
                            kaisei: kaisei,
                          ),
                          _ChapterItem(
                            number: '第六站',
                            title: '天后宮',
                            kaisei: kaisei,
                          ),
                          _ChapterItem(
                            number: '第七站',
                            title: '最後真相',
                            kaisei: kaisei,
                          ),
                          const SizedBox(height: 5),
                          Center(
                            child: _PrimaryButton(
                              text: '查看明信片與專屬紀錄片',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PastMediaPage(),
                                  ),
                                );
                              },
                              kaisei: kaisei,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

class _PastPhoto extends StatelessWidget {
  final String assetPath;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _PastPhoto({required this.assetPath, required this.kaisei});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 174,
      height: 122,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
      decoration: BoxDecoration(
        color: _photoColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _photoBorder, width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.asset(
                assetPath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '臺南赤崁樓',
            textAlign: TextAlign.center,
            style: kaisei(size: 10, weight: FontWeight.w700, color: _darkBrown),
          ),
        ],
      ),
    );
  }
}

class _ChapterItem extends StatelessWidget {
  final String number;
  final String title;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _ChapterItem({
    required this.number,
    required this.title,
    required this.kaisei,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: kaisei(size: 14, weight: FontWeight.w700, color: _darkText),
          ),
          Text(
            '$number：',
            style: kaisei(size: 14, weight: FontWeight.w700, color: _darkText),
          ),
          Expanded(
            child: Text(
              title,
              style: kaisei(
                size: 14,
                weight: FontWeight.w700,
                color: _darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _BackButton({required this.onTap, required this.kaisei});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.95 : 1.0;

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
        child: Text(
          '<< 返回',
          style: widget.kaisei(
            size: 16,
            weight: FontWeight.w700,
            color: const Color(0xFFE8DCC6),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _PrimaryButton({
    required this.text,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
          width: 225,
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _buttonBorder, width: 2),
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.2),
              radius: 1.15,
              colors: [_buttonCenter, _buttonCenter, _buttonOuter],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: widget.kaisei(
              size: 16,
              weight: FontWeight.w400,
              color: const Color(0xFFEBE1C7),
            ),
          ),
        ),
      ),
    );
  }
}
