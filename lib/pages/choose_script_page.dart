import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_responsive.dart';
import '../block/navigationbar.dart';
import 'script_detail_page.dart';

const Color _pageColor = AppColors.background;
const Color _darkBrown = AppColors.darkBrown;
const Color _ticketText = AppColors.textPrimary;
const Color _ticketSubText = AppColors.softBrown;
const Color _seeMoreColor = AppColors.secondaryRed;

class ChooseScriptPage extends StatefulWidget {
  final Map<String, dynamic>? generatedScript;
  final String cityName;
  final String townName;
  final List<String> transportation;

  const ChooseScriptPage({
    super.key,
    this.generatedScript,
    this.cityName = '',
    this.townName = '',
    this.transportation = const [],
  });

  @override
  State<ChooseScriptPage> createState() => _ChooseScriptPageState();
}

class _ChooseScriptPageState extends State<ChooseScriptPage> {
  static const double designWidth = 360.0;
  static const double designHeight = 640.0;
  static const double minScale = 0.85;
  static const double maxScale = 1.25;

  int currentIndex = 1;
  late List<_ScriptData> scripts;
  @override
  void initState() {
    super.initState();
    scripts = _buildScripts();

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

  List<_ScriptData> _buildScripts() {
    final dynamic result =
        widget.generatedScript?['Result'] ?? widget.generatedScript?['result'];

    if (result is! List) {
      return [];
    }

    final List<_ScriptData> resultScripts = [];

    for (final item in result) {
      if (item is! Map) {
        continue;
      }

      final String storyId = item['story_id']?.toString().trim() ?? '';

      if (storyId.isEmpty) {
        continue;
      }

      final dynamic storyInfo = item['story'];

      if (storyInfo is! Map) {
        continue;
      }

      final String title =
          storyInfo['story_title']?.toString().trim().isNotEmpty == true
          ? storyInfo['story_title'].toString().trim()
          : '未命名劇本';

      final String description =
          storyInfo['story_synopsis']?.toString().trim() ?? '';

      final String apiCity = storyInfo['city_name']?.toString().trim() ?? '';
      final String apiDistrict =
          storyInfo['district_name']?.toString().trim() ?? '';

      final String location = [
        apiCity.isNotEmpty ? apiCity : widget.cityName,
        apiDistrict.isNotEmpty ? apiDistrict : widget.townName,
      ].where((value) => value.trim().isNotEmpty).join(' ');

      final dynamic apiTransport = storyInfo['sd_transport'];
      final List<String> transportList = apiTransport is List
          ? apiTransport.map((e) => e.toString()).toList()
          : widget.transportation;
      final String transport = transportList.join('、');

      final dynamic badges = storyInfo['story_badge'];
      final List<String> badgeNames = badges is List
          ? badges
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : [];
      final String postcards = storyInfo['story_postcards']?.toString() ?? '0';

      final String badgeText = badgeNames.isEmpty
          ? '徽章(0)'
          : '徽章 ${badgeNames.join('、')}';

      resultScripts.add(
        _ScriptData(
          storyId: storyId,
          title: title,
          description: description,
          reward: '明信片($postcards張) /徽章類別 $badgeText',
          location: location.isEmpty ? '未指定地區' : location,
          transport: transport.isEmpty ? '未指定交通' : transport,
          story: Map<String, dynamic>.from(item),
        ),
      );
    }

    return resultScripts;
  }

  void openScriptDetail(_ScriptData script) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScriptDetailPage(
          title: script.title,
          storyId: script.storyId,
          generatedScript: script.story,
          allGeneratedScripts: widget.generatedScript,
          cityName: widget.cityName,
          townName: widget.townName,
          transportation: widget.transportation,
        ),
      ),
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
                                        _OutlinedTitle(text: '劇本檔案館'),
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
                                        style: AppTextStyles.bodySmallBold
                                            .copyWith(color: _darkBrown),
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
  final String storyId;
  final String title;
  final String description;
  final String reward;
  final String location;
  final String transport;
  final Map<String, dynamic> story;

  const _ScriptData({
    required this.storyId,
    required this.title,
    required this.description,
    required this.reward,
    required this.location,
    required this.transport,
    required this.story,
  });
}

class _ScriptTicket extends StatefulWidget {
  final _ScriptData script;
  final VoidCallback onTap;
  final VoidCallback onSeeMore;

  const _ScriptTicket({
    required this.script,
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
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: _ticketText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.script.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelWide
                            .copyWith(color: _ticketText)
                            .copyWith(height: 1.24),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '預計獲得：${widget.script.reward}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.microLabelWide.copyWith(
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
                      Expanded(
                        child: _TicketChip(
                          text: widget.script.location,
                          maxWidth: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 5),
                      _SeeMoreButton(onTap: widget.onSeeMore),
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
  final double maxWidth;

  const _TicketChip({required this.text, this.maxWidth = 84});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.postcardLine, width: 1),
        gradient: const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.15,
          colors: [AppColors.paper, AppColors.paper, Color(0xFFE5D7B2)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTextStyles.microLabelWide.copyWith(color: _darkBrown),
      ),
    );
  }
}

class _SeeMoreButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SeeMoreButton({required this.onTap});

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
                  style: AppTextStyles.label.copyWith(color: _seeMoreColor),
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
  const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = AppTextStyles.displayMedium
        .copyWith(color: _darkBrown)
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
          style: AppTextStyles.displayMedium.copyWith(color: Colors.white),
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
