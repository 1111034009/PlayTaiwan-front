import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../block/navigationbar.dart';
import 'script_detail_page.dart';

// ============================================================
// 頁面主要配色
// ============================================================

const Color _pageColor = Color(0xFFB9ACA2);
const Color _darkBrown = Color(0xFF3D2D2B);
// const Color _darkText = Color(0xFF301717);
const Color _ticketText = Color(0xFF301717);
const Color _ticketSubText = Color(0xFF6D625B);

// ============================================================
// 票券「觀看更多」配色
// ============================================================

const Color _seeMoreColor = Color(0xFF871E0C);

// ============================================================
// 劇本選擇頁
// ============================================================

class ChooseScriptPage extends StatefulWidget {
  const ChooseScriptPage({super.key});

  @override
  State<ChooseScriptPage> createState() => _ChooseScriptPageState();
}

class _ChooseScriptPageState extends State<ChooseScriptPage> {
  // ============================================================
  // 設計寬度
  // ============================================================

  static const double designWidth = 360.0;

  // ============================================================
  // 頁面縮放範圍
  // ============================================================

  static const double minScale = 0.85;
  static const double maxScale = 1.25;

  // ============================================================
  // 底部導覽目前選取項目
  // ============================================================

  int currentIndex = 1;

  // ============================================================
  // 劇本資料
  // ============================================================

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

  // ============================================================
  // 初始化頁面
  // ============================================================

  @override
  void initState() {
    super.initState();

    // 設定系統狀態列與底部系統導覽列顏色
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

  // ============================================================
  // Kaisei 字體統一設定
  // ============================================================

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

  // ============================================================
  // 返回首頁
  // ============================================================

  void goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ============================================================
  // 開啟劇本詳細頁
  // ============================================================

  void openScriptDetail(_ScriptData script) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScriptDetailPage(title: script.title)),
    );
  }

  // ============================================================
  // 根據螢幕寬度計算設計縮放比例
  // ============================================================

  double _getScale(double availableWidth) {
    return (availableWidth / designWidth).clamp(minScale, maxScale);
  }

  // ============================================================
  // 頁面主要建構
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,

      // ==========================================================
      // 主內容區
      // ==========================================================
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ======================================================
            // 取得目前螢幕寬度
            // ======================================================

            final double screenWidth = constraints.maxWidth;

            // ======================================================
            // 計算目前畫面縮放比例
            // ======================================================

            final double scale = _getScale(screenWidth);

            // ======================================================
            // 根據縮放比例計算設計畫布高度
            // ======================================================

            final double designHeight = constraints.maxHeight / scale;

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
                      height: designHeight,

                      // ==================================================
                      // 固定設計尺寸內容
                      // ==================================================
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // ==================================================
                          // 頁面背景
                          // ==================================================
                          Positioned.fill(child: Container(color: _pageColor)),

                          // ==================================================
                          // 劇本列表
                          // ==================================================
                          Positioned.fill(
                            child: ScrollConfiguration(
                              behavior: const _NoScrollbarScrollBehavior(),
                              child: ListView(
                                physics: const BouncingScrollPhysics(),

                                // ==================================================
                                // 列表內距
                                // ==================================================
                                padding: const EdgeInsets.only(
                                  left: 15,
                                  right: 15,
                                  top: 30,
                                  bottom: 75,
                                ),

                                children: [
                                  // ==================================================
                                  // 劇本檔案館標題
                                  // ==================================================
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // ==================================================
                                        // 卷軸圖示
                                        // ==================================================
                                        Image.asset(
                                          'img/Scroll.png',
                                          width: 27,
                                          height: 27,
                                          fit: BoxFit.contain,
                                        ),

                                        const SizedBox(width: 7),

                                        // ==================================================
                                        // 標題文字
                                        // ==================================================
                                        _OutlinedTitle(
                                          text: '劇本檔案館',
                                          kaisei: kaisei,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // ==================================================
                                  // 頁面說明文字
                                  // ==================================================
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

                                  // ==================================================
                                  // 劇本票券列表
                                  // ==================================================
                                  for (final script in scripts)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),

                                      child: _ScriptTicket(
                                        script: script,
                                        kaisei: kaisei,

                                        // ==================================================
                                        // 點擊整張票券直接進入詳細頁
                                        // ==================================================
                                        onTap: () {
                                          openScriptDetail(script);
                                        },

                                        // ==================================================
                                        // 點擊觀看更多直接進入詳細頁
                                        // ==================================================
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

      // ============================================================
      // 底部導覽列
      // ============================================================
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ============================================================
// 劇本資料
// ============================================================

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

// ============================================================
// 劇本票券
// ============================================================

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
  // ============================================================
  // 滑鼠互動狀態
  // ============================================================

  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // 根據互動狀態決定票券縮放
    // ==========================================================

    final double scale = pressing
        ? 0.985
        : hovering
        ? 1.01
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,

      // ==========================================================
      // 滑鼠移入
      // ==========================================================
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      // ==========================================================
      // 滑鼠移出
      // ==========================================================
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        // ==========================================================
        // 點擊整張票券
        // ==========================================================
        onTap: widget.onTap,

        // ==========================================================
        // 按下票券
        // ==========================================================
        onTapDown: (_) {
          setState(() {
            pressing = true;
          });
        },

        // ==========================================================
        // 放開票券
        // ==========================================================
        onTapUp: (_) {
          setState(() {
            pressing = false;
          });
        },

        // ==========================================================
        // 取消按壓
        // ==========================================================
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

            // ========================================================
            // 票券主要內容
            // ========================================================
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ==================================================
                // 票券背景圖片
                // ==================================================
                Positioned.fill(
                  child: Image.asset('img/ticket.png', fit: BoxFit.fill),
                ),

                // ==================================================
                // 劇本標題、介紹、獎勵
                // ==================================================
                Positioned(
                  left: 13,
                  top: 9,
                  width: 246,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ==================================================
                      // 劇本標題
                      // ==================================================
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

                      // ==================================================
                      // 劇本簡介
                      // ==================================================
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

                      // ==================================================
                      // 預計獲得
                      // ==================================================
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

                // ==================================================
                // 地點、交通方式、觀看更多
                // ==================================================
                Positioned(
                  left: 12,
                  top: 135,
                  width: 247,
                  height: 25,

                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,

                    children: [
                      // ==================================================
                      // 地點
                      // ==================================================
                      _TicketChip(
                        text: widget.script.location,
                        kaisei: widget.kaisei,
                      ),

                      const SizedBox(width: 5),

                      // ==================================================
                      // 交通方式
                      // ==================================================
                      _TicketChip(
                        text: widget.script.transport,
                        kaisei: widget.kaisei,
                      ),

                      const Spacer(),

                      // ==================================================
                      // 觀看更多
                      // ==================================================
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

// ============================================================
// 票券資訊標籤
// ============================================================

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

        // ========================================================
        // 標籤左右內距
        // ========================================================
        padding: const EdgeInsets.symmetric(horizontal: 9),

        alignment: Alignment.center,

        constraints: const BoxConstraints(maxWidth: 84),

        // ========================================================
        // 標籤外觀
        // ========================================================
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

        // ========================================================
        // 標籤文字
        // ========================================================
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

// ============================================================
// 觀看更多按鈕
// ============================================================

class _SeeMoreButton extends StatefulWidget {
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  final VoidCallback onTap;

  const _SeeMoreButton({required this.kaisei, required this.onTap});

  @override
  State<_SeeMoreButton> createState() => _SeeMoreButtonState();
}

class _SeeMoreButtonState extends State<_SeeMoreButton> {
  // ============================================================
  // 滑鼠互動狀態
  // ============================================================

  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // 根據互動狀態決定縮放
    // ==========================================================

    final double scale = pressing
        ? 0.95
        : hovering
        ? 1.08
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,

      // ==========================================================
      // 滑鼠移入
      // ==========================================================
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },

      // ==========================================================
      // 滑鼠移出
      // ==========================================================
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },

      child: GestureDetector(
        // ==========================================================
        // 點擊觀看更多
        // ==========================================================
        onTap: widget.onTap,

        // ==========================================================
        // 按下
        // ==========================================================
        onTapDown: (_) {
          setState(() {
            pressing = true;
          });
        },

        // ==========================================================
        // 放開
        // ==========================================================
        onTapUp: (_) {
          setState(() {
            pressing = false;
          });
        },

        // ==========================================================
        // 取消按壓
        // ==========================================================
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
                // ==================================================
                // 觀看更多文字
                // ==================================================
                Text(
                  '觀看更多',
                  style: widget.kaisei(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _seeMoreColor,
                  ),
                ),

                const SizedBox(width: 1),

                // ==================================================
                // 觀看更多圖示
                // ==================================================
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

// ============================================================
// 劇本檔案館標題
// ============================================================

class _OutlinedTitle extends StatelessWidget {
  final String text;

  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _OutlinedTitle({required this.text, required this.kaisei});

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // 標題外框文字樣式
    // ==========================================================

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
        // ========================================================
        // 外框
        // ========================================================
        Text(text, style: outlineStyle),

        // ========================================================
        // 內部白色文字
        // ========================================================
        Text(
          text,
          style: kaisei(size: 24, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}

// ============================================================
// 關閉 ScrollView 預設 Scrollbar / Overscroll 效果
// ============================================================

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  const _NoScrollbarScrollBehavior();

  // ==========================================================
  // 隱藏 Scrollbar
  // ==========================================================

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  // ==========================================================
  // 隱藏 Overscroll Indicator
  // ==========================================================

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
