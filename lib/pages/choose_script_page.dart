import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../block/navigationbar.dart';
import 'script_detail_page.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _ticketText = AppColors.textPrimary;
const Color _ticketSubText = Color(0xFF6D625B);
const Color _seeMoreColor = Color(0xFF871E0C);

class ChooseScriptPage extends StatefulWidget {
  const ChooseScriptPage({super.key});

  @override
  State<ChooseScriptPage> createState() => _ChooseScriptPageState();
}

class _ChooseScriptPageState extends State<ChooseScriptPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;
  static const double minScale = 0.85;
  static const double maxScale = 1.25;

  int currentIndex = 1;

  final List<_ScriptData> scripts = const [
    _ScriptData(
      title: '府城儒生失落卷',
      description: '清朝年間，一位準備赴考的考生在府城遺失了他的重要的記憶。尋著百年軌跡，找回失落記憶……',
      reward: '徽章(文化系列) / 明信片(5)',
      location: '台南市',
      transport: '公車、步行',
    ),
    _ScriptData(
      title: '府城古城謎影',
      description: '沿著古城留下的線索前進，在老街、古蹟與巷弄之間尋找被時間藏起來的秘密。',
      reward: '徽章(古蹟系列) / 明信片(5)',
      location: '台南市',
      transport: '步行、捷運',
    ),
    _ScriptData(
      title: '港都消失的航線',
      description: '一張神秘的舊船票，帶你踏上港都尋寶之旅。你能找到消失多年的航線嗎？',
      reward: '徽章(探索系列) / 明信片(5)',
      location: '高雄市',
      transport: '捷運、步行',
    ),
  ];

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

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _darkBrown,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  void openScriptDetail(_ScriptData script) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScriptDetailPage(title: script.title)),
    );
  }

  double _getScale(double availableWidth) {
    return AppResponsive.scale(
      availableWidth: availableWidth,
      availableHeight: designHeight,
      designWidth: designWidth,
      designHeight: designHeight,
      min: minScale,
      max: maxScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double scale = _getScale(screenWidth);
            final double contentHeight = constraints.maxHeight / scale;

            return ColoredBox(
              color: _pageColor,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: designWidth,
                      height: contentHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: Container(color: _pageColor)),
                          Positioned.fill(
                            child: ScrollConfiguration(
                              behavior: const _NoScrollbarScrollBehavior(),
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  left: 15,
                                  right: 15,
                                  top: 50,
                                  bottom: 75,
                                ),
                                children: [
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'img/Scroll.png',
                                          width: 27,
                                          height: 27,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 7),
                                        _OutlinedTitle(
                                          text: '劇本檔案館',
                                          kaisei: kaisei,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFE9DDC6,
                                        ).withOpacity(0.88),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF8A7163,
                                          ).withOpacity(0.30),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '選擇您感興趣的劇本，點選車票獲得地圖',
                                        textAlign: TextAlign.center,
                                        style: kaisei(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: _darkBrown,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  for (final script in scripts)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _ScriptTicket(
                                        script: script,
                                        kaisei: kaisei,
                                        onTap: () {
                                          openScriptDetail(script);
                                        },
                                        onSeeMore: () {
                                          openScriptDetail(script);
                                        },
                                      ),
                                    ),
                                ],
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
          },
        ),
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

class _ScriptData {
  final String title;
  final String description;
  final String reward;
  final String location;
  final String transport;

  const _ScriptData({
    required this.title,
    required this.description,
    required this.reward,
    required this.location,
    required this.transport,
  });
}

class _ScriptTicket extends StatefulWidget {
  final _ScriptData script;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;
  final VoidCallback onTap;
  final VoidCallback onSeeMore;

  const _ScriptTicket({
    required this.script,
    required this.kaisei,
    required this.onTap,
    required this.onSeeMore,
  });

  @override
  State<_ScriptTicket> createState() => _ScriptTicketState();
}

class _ScriptTicketState extends State<_ScriptTicket> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.985
        : hovering
        ? 1.01
        : 1.0;

    return MouseRegion(
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
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 330,
            height: 169,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset('img/ticket.png', fit: BoxFit.fill),
                ),
                Positioned(
                  left: 13,
                  top: 9,
                  width: 246,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.script.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.kaisei(
                          size: 18,
                          weight: FontWeight.w700,
                          color: _ticketText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.script.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: widget
                            .kaisei(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: _ticketText,
                            )
                            .copyWith(height: 1.24),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '預計獲得：${widget.script.reward}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.kaisei(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: _ticketSubText,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 135,
                  width: 247,
                  height: 25,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TicketChip(
                        text: widget.script.location,
                        kaisei: widget.kaisei,
                      ),
                      const SizedBox(width: 5),
                      _TicketChip(
                        text: widget.script.transport,
                        kaisei: widget.kaisei,
                      ),
                      const Spacer(),
                      _SeeMoreButton(
                        kaisei: widget.kaisei,
                        onTap: widget.onSeeMore,
                      ),
                    ],
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

class _TicketChip extends StatelessWidget {
  final String text;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _TicketChip({required this.text, required this.kaisei});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: 0,
      child: Container(
        height: 23,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxWidth: 84),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF8D7B6E), width: 1),
          gradient: const RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.15,
            colors: [Color(0xFFEBE1C7), Color(0xFFEBE1C7), Color(0xFFE5D7B2)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: kaisei(size: 11.5, weight: FontWeight.w700, color: _darkBrown),
        ),
      ),
    );
  }
}

class _SeeMoreButton extends StatefulWidget {
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;
  final VoidCallback onTap;

  const _SeeMoreButton({required this.kaisei, required this.onTap});

  @override
  State<_SeeMoreButton> createState() => _SeeMoreButtonState();
}

class _SeeMoreButtonState extends State<_SeeMoreButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.95
        : hovering
        ? 1.08
        : 1.0;

    return MouseRegion(
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
          curve: Curves.easeOut,
          child: SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  '觀看更多',
                  style: widget.kaisei(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _seeMoreColor,
                  ),
                ),
                const SizedBox(width: 1),
                Image.asset(
                  'img/see_more.png',
                  width: 13,
                  height: 13,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedTitle extends StatelessWidget {
  final String text;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _OutlinedTitle({required this.text, required this.kaisei});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = kaisei(size: 24, weight: FontWeight.w700)
        .copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..color = _darkBrown,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: outlineStyle),
        Text(
          text,
          style: kaisei(size: 24, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
