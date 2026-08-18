import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../block/navigationbar.dart';
import 'past_detail_page.dart';

const Color _pageColor = Color(0xFF4F4141);
const Color _subtitleText = Color(0xCCFFFFFF);
const Color _ticketText = Color(0xFF301717);
const Color _seeMoreColor = Color(0xFF871E0C);

class PastPage extends StatefulWidget {
  const PastPage({super.key});

  @override
  State<PastPage> createState() => _PastPageState();
}

class _PastPageState extends State<PastPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;
  static const double contentScale = 1.04;

  int currentIndex = 3;

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
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _ticketText,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  void openPastRecord() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PastDetailPage(title: '府城儒生失落卷', completedDate: '2026.0809'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Center(
        child: Transform.scale(
          scale: contentScale,
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
                    left: 0,
                    right: 0,
                    top: 20,
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'img/Scroll.png',
                              width: 27,
                              height: 27,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 7),
                            _OutlinedTitle(text: '收藏館', kaisei: kaisei),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '查看你過往紀錄',
                          textAlign: TextAlign.center,
                          style: kaisei(
                            size: 14,
                            weight: FontWeight.w700,
                            color: _subtitleText,
                          ).copyWith(height: 1.1),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 80,
                    bottom: 0,
                    child: ScrollConfiguration(
                      behavior: const _NoScrollbarScrollBehavior(),
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 15,
                          right: 15,
                          top: 7,
                          bottom: 110,
                        ),
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _PastTicket(
                              kaisei: kaisei,
                              onTap: openPastRecord,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

class _PastTicket extends StatefulWidget {
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final VoidCallback onTap;

  const _PastTicket({required this.kaisei, required this.onTap});

  @override
  State<_PastTicket> createState() => _PastTicketState();
}

class _PastTicketState extends State<_PastTicket> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.985
        : hovering
        ? 1.008
        : 1.0;

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
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 330,
            height: 133,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'img/use_ticket.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBE1C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF8D7B6E)),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 15,
                  top: 16,
                  width: 91,
                  height: 94,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4D6B7),
                      border: Border.all(
                        color: const Color(0xFF8C8176),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 120,
                  top: 15,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '府城儒生失落卷',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.kaisei(
                          size: 17,
                          weight: FontWeight.w900,
                          color: _seeMoreColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '尋著百年軌跡，找回失落記憶...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: widget
                            .kaisei(
                              size: 11.5,
                              weight: FontWeight.w700,
                              color: _ticketText,
                            )
                            .copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: 12,
                  child: _ViewButton(
                    kaisei: widget.kaisei,
                    onTap: widget.onTap,
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

class _ViewButton extends StatefulWidget {
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final VoidCallback onTap;

  const _ViewButton({required this.kaisei, required this.onTap});

  @override
  State<_ViewButton> createState() => _ViewButtonState();
}

class _ViewButtonState extends State<_ViewButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.95
        : hovering
        ? 1.07
        : 1.0;

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
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE4D4B5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8D7B6E), width: 1),
            ),
            child: Text(
              '查看資料→',
              textAlign: TextAlign.center,
              style: widget.kaisei(
                size: 10,
                weight: FontWeight.w900,
                color: _ticketText,
              ),
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
            ..color = _ticketText,
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
