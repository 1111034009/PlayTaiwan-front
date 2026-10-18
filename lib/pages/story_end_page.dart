import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../api/story_api.dart';
import 'vlog_check_page.dart';

import '../block/navigationbar.dart';

const Color _backgroundColor = AppColors.storyBackground;
const Color _titleColor = Colors.white;
const Color _subtitleColor = Color(0xCCFFFFFF);

const Color _cardBackground = Color(0xFFF4F4F4);
const Color _cardBorder = Color(0xFFDEB019);
const Color _cardText = AppColors.textPrimary;

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

const String _badgeAsset = 'img/Badge_location.png';

class StoryEndPage extends StatefulWidget {
  final String storyId;

  const StoryEndPage({super.key, this.storyId = ''});

  @override
  State<StoryEndPage> createState() => _StoryEndPageState();
}

class _StoryEndPageState extends State<StoryEndPage> {
  static const double designWidth = 430;
  static const double designHeight = 760;

  int currentIndex = 1;

  Map<String, dynamic>? _result;

  final GlobalKey<_EndGachaMachineState> _gachaKey =
      GlobalKey<_EndGachaMachineState>();

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _backgroundColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void goVlog() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VlogCheckPage(storyId: widget.storyId)),
    );
  }

  void startGacha() {
    _gachaKey.currentState?.startGacha();
  }

  void _onResult(Map<String, dynamic> result) {
    if (!mounted) return;

    setState(() {
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      extendBody: true,
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
                const Positioned.fill(
                  child: ColoredBox(color: _backgroundColor),
                ),

                // 抽取失敗時點擊畫面可重試。
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _result == null ? startGacha : null,
                    child: const SizedBox.expand(),
                  ),
                ),

                // 標題。
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.scale(
                        scale: 1.07,
                        child: _OutlinedTitle(text: '完成遊戲關卡'),
                      ),
                    ),
                  ),
                ),

                // 副標題。
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.scale(
                        scale: 1.06,
                        child: Text(
                          '尋回真相',
                          style: AppTextStyles.subtitle
                              .copyWith(color: _subtitleColor)
                              .copyWith(height: 1, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ),
                ),

                // 扭蛋機。
                Positioned(
                  left: 80,
                  top: 115,
                  width: 270,
                  height: 281,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: 1.08,
                      alignment: Alignment.topCenter,
                      child: _EndGachaMachine(
                        key: _gachaKey,
                        storyId: widget.storyId,
                        onResult: _onResult,
                      ),
                    ),
                  ),
                ),

                // 結果小卡。
                Positioned(
                  left: 65,
                  top: 440,
                  width: 300,
                  height: 130,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: 1.08,
                      alignment: Alignment.center,
                      child: _EndResultCard(result: _result),
                    ),
                  ),
                ),

                // 過往提示。
                Positioned(
                  top: 590,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.scale(
                        scale: 1.06,
                        child: Text(
                          '回憶紀錄片請至過往查看',
                          style: AppTextStyles.bodyEmphasisBold
                              .copyWith(
                                color: const Color.fromARGB(188, 255, 255, 255),
                              )
                              .copyWith(height: 1, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),

                // 前往製作 Vlog。
                if (_result != null)
                  Positioned(
                    left: 45,
                    right: 45,
                    top: 620,
                    height: 54,
                    child: _EndButton(text: '前往製作 Vlog', onTap: goVlog),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }
}

// ============================================================
// 標題
// ============================================================

class _OutlinedTitle extends StatelessWidget {
  final String text;
  const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: AppTextStyles.display
              .copyWith(color: _titleColor)
              .copyWith(
                height: 1,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3.5
                  ..color = Colors.black,
              ),
        ),
        Text(
          text,
          style: AppTextStyles.display
              .copyWith(color: Colors.white)
              .copyWith(height: 1),
        ),
      ],
    );
  }
}

// ============================================================
// 扭蛋機
// ============================================================

class _EndGachaMachine extends StatefulWidget {
  final String storyId;
  final ValueChanged<Map<String, dynamic>> onResult;

  const _EndGachaMachine({
    super.key,
    required this.storyId,
    required this.onResult,
  });

  @override
  State<_EndGachaMachine> createState() => _EndGachaMachineState();
}

class _EndGachaMachineState extends State<_EndGachaMachine>
    with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final AnimationController _knobController;

  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _knobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startGacha();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _knobController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _result;

  // 開始抽扭蛋。
  Future<void> startGacha() async {
    if (_isPlaying) {
      return;
    }

    if (widget.storyId.isEmpty) {
      _showError('找不到劇本 ID');
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    final Future<Object> draw = _result != null
        ? Future<Object>.value(_result!)
        : StoryApi.drawBadge(
            storyId: widget.storyId,
          ).then<Object>((value) => value).catchError((Object e) => e);

    await Future.wait([
      _knobController.forward(from: 0),
      _shakeController.forward(from: 0),
    ]);

    final Object out = await draw;

    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = false;
    });

    if (out is! Map<String, dynamic>) {
      _showError(out.toString().replaceFirst('Exception: ', ''));
      return;
    }

    _result = out;

    widget.onResult(out);

    await _showRewardDialog(out);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // 顯示全螢幕黑幕與獎勵動畫。
  Future<void> _showRewardDialog(Map<String, dynamic> result) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: '獎勵動畫',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullScreenRewardOverlay(result: result);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final t = _shakeController.value;

        final shake = sin(t * pi * 8) * (1 - t) * 0.017;

        return Transform.rotate(
          angle: shake,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 機身。
          Positioned(
            left: 52,
            right: 52,
            top: 140,
            height: 132,
            child: _buildMachineBody(),
          ),

          // 透明球。
          Positioned(top: 10, child: _buildGlobe()),

          // 頂蓋。
          Positioned(top: 1, child: _buildTopCap()),

          // 旋鈕。
          Positioned(top: 180, child: _buildKnob()),
        ],
      ),
    );
  }

  // ==========================================================
  // 頂蓋
  // ==========================================================

  Widget _buildTopCap() {
    return Container(
      width: 62,
      height: 18,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F4EA), Color(0xFFB9B0A4), Color(0xFFEDE7DC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF83786C), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 透明球
  // ==========================================================

  Widget _buildGlobe() {
    const double size = 155;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.38, -0.48),
          radius: 1.05,
          colors: [Color(0xFFFDFCF8), Color(0xDDEBF2EC), Color(0x8899B9AC)],
          stops: [0.0, 0.58, 1.0],
        ),
        border: Border.all(color: const Color(0xFFF8F4EA), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            _buildCapsulesInsideGlobe(),
            Positioned(
              left: 19,
              top: 20,
              child: Transform.rotate(
                angle: -0.30,
                child: Container(
                  width: 12,
                  height: 49,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 球內膠囊
  // ==========================================================

  Widget _buildCapsulesInsideGlobe() {
    const colors = <Color>[
      Color(0xFFF3B68E),
      Color(0xFFF5D47B),
      Color(0xFF91C8B3),
      Color(0xFF8FB8D8),
      Color(0xFFDCA9C9),
      Color(0xFFE8A77D),
    ];

    const positions = <Offset>[
      Offset(0.32, 0.46),
      Offset(0.49, 0.43),
      Offset(0.66, 0.47),
      Offset(0.25, 0.59),
      Offset(0.41, 0.58),
      Offset(0.57, 0.59),
      Offset(0.73, 0.63),
      Offset(0.34, 0.73),
      Offset(0.50, 0.72),
      Offset(0.66, 0.76),
      Offset(0.43, 0.86),
      Offset(0.58, 0.86),
    ];

    return Stack(
      children: List.generate(positions.length, (index) {
        final point = positions[index];

        final size = index % 3 == 0 ? 23.0 : 21.0;

        return Positioned(
          left: 146 * point.dx - size / 2,
          top: 146 * point.dy - size / 2,
          child: Transform.rotate(
            angle: index.isEven ? 0.16 : -0.14,
            child: _EndCapsule(
              size: size,
              color: colors[index % colors.length],
            ),
          ),
        );
      }),
    );
  }

  // ==========================================================
  // 機身
  // ==========================================================

  Widget _buildMachineBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB54830), Color(0xFF8E2B1B), Color(0xFF65180E)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF451008), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 中間米白色區塊。
          Positioned(
            top: 37,
            left: 20,
            right: 20,
            height: 47,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF7F1E7), Color(0xFFC8BCAE)],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF786D61), width: 1.2),
              ),
            ),
          ),

          // 出球口。
          Positioned(
            left: 14,
            right: 14,
            bottom: 10,
            height: 30,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3A0D08),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF220604), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 旋鈕
  // ==========================================================

  Widget _buildKnob() {
    return AnimatedBuilder(
      animation: _knobController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _knobController.value * pi * 4,
          child: child,
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: _isPlaying
                ? const [Color(0xFFC2BBB0), Color(0xFF877C6E)]
                : const [Color(0xFFF8F3EA), Color(0xFFBEB5A8)],
          ),
          border: Border.all(color: const Color(0xFF675C51), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 30,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF81766A),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 全螢幕獎勵動畫
// ============================================================

class _FullScreenRewardOverlay extends StatefulWidget {
  final Map<String, dynamic> result;

  const _FullScreenRewardOverlay({required this.result});

  @override
  State<_FullScreenRewardOverlay> createState() =>
      _FullScreenRewardOverlayState();
}

class _FullScreenRewardOverlayState extends State<_FullScreenRewardOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _blackController;
  late final AnimationController _capsuleController;
  late final AnimationController _openController;
  late final AnimationController _badgeController;

  final Color _capsuleColor = const Color(0xFFF3B68E);

  Map<String, dynamic> get _badge {
    final dynamic badge = widget.result['badge'];

    return badge is Map ? Map<String, dynamic>.from(badge) : {};
  }

  String get _badgeImage => _badge['b_image']?.toString().trim() ?? '';

  String get _badgeSeries {
    final String series = _badge['b_fication']?.toString().trim() ?? '';

    return series.isEmpty ? '' : '$series系列';
  }

  String get _badgeName => _badge['b_name']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();

    _blackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _capsuleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _playAnimation();
  }

  @override
  void dispose() {
    _blackController.dispose();
    _capsuleController.dispose();
    _openController.dispose();
    _badgeController.dispose();

    super.dispose();
  }

  // ==========================================================
  // 完整獎勵動畫流程
  // ==========================================================

  Future<void> _playAnimation() async {
    await _blackController.forward();

    if (!mounted) {
      return;
    }

    await _capsuleController.forward();

    if (!mounted) {
      return;
    }

    await _openController.forward();

    if (!mounted) {
      return;
    }

    await _badgeController.forward();
  }

  // 點擊黑幕後關閉動畫並回到原本頁面。
  void _closeOverlay() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeOverlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ==================================================
            // 全螢幕黑色遮罩
            // ==================================================
            AnimatedBuilder(
              animation: _blackController,
              builder: (context, child) {
                return ColoredBox(
                  color: Colors.black.withOpacity(
                    0.82 * _blackController.value,
                  ),
                );
              },
            ),

            // ==================================================
            // 中央膠囊與徽章動畫
            // ==================================================
            Center(child: IgnorePointer(child: _buildRewardSequence())),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 建立膠囊出現、打開與徽章獲得動畫
  // ==========================================================

  Widget _buildRewardSequence() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _capsuleController,
        _openController,
        _badgeController,
      ]),
      builder: (context, child) {
        // ------------------------------------------------------
        // 膠囊動畫。
        // ------------------------------------------------------

        final capsuleT = Curves.easeOutBack.transform(_capsuleController.value);

        // ------------------------------------------------------
        // 打開動畫
        // ------------------------------------------------------

        final openT = Curves.easeInOutCubic.transform(_openController.value);

        // ------------------------------------------------------
        // 徽章動畫
        // ------------------------------------------------------

        final badgeT = Curves.easeOutBack.transform(_badgeController.value);

        final badgeOpacity = badgeT.clamp(0.0, 1.0).toDouble();

        // 完整膠囊淡出時，同樣保證 opacity 一定在 0~1。
        final capsuleOpacity = (1.0 - openT).clamp(0.0, 1.0).toDouble();

        // 膠囊上下分離距離。
        final halfOffset = openT * 55;

        return SizedBox(
          width: 280,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ==================================================
              // 完整膠囊出現
              // ==================================================
              Opacity(
                opacity: capsuleOpacity,
                child: Transform.scale(
                  scale: 0.2 + capsuleT * 0.8,
                  child: _RewardCapsule(size: 100, color: _capsuleColor),
                ),
              ),

              // ==================================================
              // 膠囊上半部打開
              // ==================================================
              if (_openController.value > 0)
                Transform.translate(
                  offset: Offset(0, -halfOffset),
                  child: Transform.rotate(
                    angle: -openT * 0.35,
                    child: Opacity(
                      opacity: openT.clamp(0.0, 1.0).toDouble(),
                      child: _CapsuleHalf(
                        size: 100,
                        color: _capsuleColor,
                        top: true,
                      ),
                    ),
                  ),
                ),

              // ==================================================
              // 膠囊下半部打開
              // ==================================================
              if (_openController.value > 0)
                Transform.translate(
                  offset: Offset(0, halfOffset),
                  child: Transform.rotate(
                    angle: openT * 0.35,
                    child: Opacity(
                      opacity: openT.clamp(0.0, 1.0).toDouble(),
                      child: _CapsuleHalf(
                        size: 100,
                        color: _capsuleColor,
                        top: false,
                      ),
                    ),
                  ),
                ),

              // ==================================================
              // 徽章獲得
              // ==================================================
              if (_badgeController.value > 0)
                Transform.translate(
                  offset: Offset(0, -10 - badgeT * 5),
                  child: Opacity(
                    opacity: badgeOpacity,
                    child: Transform.scale(
                      scale: 0.2 + badgeT * 0.8,
                      child: Container(
                        width: 160,
                        height: 160,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF9F3DF),
                          border: Border.all(
                            color: const Color(0xFFDEB019),
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xCC000000),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _badgeImage.isEmpty
                              ? Image.asset(
                                  _badgeAsset,
                                  fit: BoxFit.contain,
                                  width: 150,
                                  height: 175,
                                )
                              : Image.network(
                                  _badgeImage,
                                  fit: BoxFit.contain,
                                  width: 160,
                                  height: 160,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      _badgeAsset,
                                      fit: BoxFit.contain,
                                      width: 160,
                                      height: 160,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ==================================================
              // 徽章文字
              // ==================================================
              if (_badgeController.value > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: badgeOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_badgeSeries.isNotEmpty)
                          Text(
                            _badgeSeries,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.captionBold.copyWith(
                              color: const Color(0xFFFFF4C9),
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 5),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _badgeName.isEmpty ? '獲得新徽章' : _badgeName,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyEmphasisBold.copyWith(
                            color: const Color(0xFFFFF4C9),
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 5),
                            ],
                          ),
                        ),
                        if (widget.result['is_new'] == false) ...[
                          const SizedBox(height: 4),
                          Text(
                            '這枚徽章你已經擁有',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.captionBold.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// 球內膠囊
// ============================================================

class _EndCapsule extends StatelessWidget {
  final double size;
  final Color color;

  const _EndCapsule({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            color,
            const Color(0xFFF9F7F2),
            const Color(0xFFEAE5DB),
          ],
          stops: const [0.0, 0.46, 0.54, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 2,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.35, -0.40),
        child: Container(
          width: size * 0.20,
          height: size * 0.08,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 獎勵膠囊
// ============================================================

class _RewardCapsule extends StatelessWidget {
  final double size;
  final Color color;

  const _RewardCapsule({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            color,
            const Color(0xFFFFFEFB),
            const Color(0xFFE9E2D8),
          ],
          stops: const [0.0, 0.47, 0.53, 1.0],
        ),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.35, -0.42),
        child: Container(
          width: size * 0.25,
          height: size * 0.11,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(40),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 膠囊半部
// ============================================================

class _CapsuleHalf extends StatelessWidget {
  final double size;
  final Color color;
  final bool top;

  const _CapsuleHalf({
    required this.size,
    required this.color,
    required this.top,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: top
                  ? [color, color, const Color(0xFFF9F7F2)]
                  : [
                      const Color(0xFFF9F7F2),
                      const Color(0xFFE9E2D8),
                      const Color(0xFFD4CCC0),
                    ],
              stops: const [0.0, 0.80, 1.0],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.88), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 結果小卡
// ============================================================

class _EndResultCard extends StatelessWidget {
  final Map<String, dynamic>? result;

  const _EndResultCard({required this.result});

  String _text(dynamic value) => value?.toString().trim() ?? '';

  List<String> _lines() {
    final Map<String, dynamic>? data = result;

    if (data == null) {
      return const ['徽章抽取中……'];
    }

    final dynamic rawBadge = data['badge'];
    final Map<String, dynamic> badge = rawBadge is Map
        ? Map<String, dynamic>.from(rawBadge)
        : {};

    final String series = _text(badge['b_fication']);
    final String name = _text(badge['b_name']);

    return [
      if (series.isNotEmpty) '徽章系列：$series',
      if (name.isNotEmpty) '徽章名稱：$name',
      '獲得狀態：${data['is_new'] == false ? '已擁有' : '新徽章'}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<String> lines = _lines();

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _cardBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _EndResultLine(text: lines[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 黃色虛線
// ============================================================

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cardBorder
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    const double insetX = -15;
    const double insetY = 0;
    const double dashWidth = 7;
    const double dashSpace = 4;
    const double radius = 5;

    final rect = Rect.fromLTRB(
      insetX,
      insetY,
      size.width - insetX,
      size.height - insetY,
    );

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final end = min(distance + dashWidth, metric.length);

        canvas.drawPath(metric.extractPath(distance, end), paint);

        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ============================================================
// 小卡文字
// ============================================================

class _EndResultLine extends StatelessWidget {
  final String text;
  const _EndResultLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.sectionTitle
          .copyWith(color: _cardText)
          .copyWith(height: 1),
    );
  }
}

// ============================================================
// 按鈕
// ============================================================

class _EndButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _EndButton({required this.text, required this.onTap});

  @override
  State<_EndButton> createState() => _EndButtonState();
}

class _EndButtonState extends State<_EndButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing
        ? 0.96
        : hovering
        ? 1.06
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
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
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle
                  .copyWith(color: AppColors.paper)
                  .copyWith(height: 1.1, letterSpacing: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
