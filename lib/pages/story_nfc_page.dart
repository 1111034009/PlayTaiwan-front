import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

import 'nfc_information_page.dart';

class StoryNfcPage extends StatefulWidget {
  const StoryNfcPage({
    super.key,
    this.locationName = '臺南孔廟',
    this.sealName = '康熙御筆',
    this.rewardText = '臺南孔廟專屬店家優惠券',
    this.showSimulationButton = true,
  });

  final String locationName;
  final String sealName;
  final String rewardText;
  final bool showSimulationButton;

  @override
  State<StoryNfcPage> createState() => _StoryNfcPageState();
}

class _StoryNfcPageState extends State<StoryNfcPage>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  late final AnimationController _sealController;

  bool _isSuccess = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _sealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _sealController.dispose();
    super.dispose();
  }

  Future<void> _simulateNfcSuccess() async {
    if (_isProcessing || _isSuccess) return;

    setState(() {
      _isProcessing = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    setState(() {
      _isSuccess = true;
      _isProcessing = false;
    });

    _sealController.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NfcInformationPage(
          locationName: widget.locationName,
          sealName: widget.sealName,
          rewardText: widget.rewardText,
        ),
      ),
    );
  }

  void _cancel() {
    if (_isProcessing) return;

    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.storyBackground,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _NfcBackground()),

            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCenterContent()),
                _buildBottomHint(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Icon(
            Icons.nfc_rounded,
            size: 18,
            color: const Color(0xFFE9DDC6).withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'NFC通訊驗證中',
              style: AppTextStyles.bodyBold.copyWith(
                color: const Color(0xFFE9DDC6),
                letterSpacing: 1.4,
              ),
            ),
          ),
          TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warmPaper,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '返回',
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.warmPaper,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _rippleController,
              builder: (context, child) {
                return SizedBox(
                  width: 270,
                  height: 270,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildRipple(
                        progress: _rippleController.value,
                        color: const Color(0xFFD8AF58),
                        maxScale: 1.0,
                      ),
                      _buildRipple(
                        progress: (_rippleController.value + 0.3) % 1.0,
                        color: AppColors.primary,
                        maxScale: 0.88,
                      ),
                      _buildSeal(),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 18),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _isSuccess ? 'NFC 感應解鎖成功！' : '請將手機靠近NFC',
                key: ValueKey<bool>(_isSuccess),
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(
                  color: _isSuccess
                      ? const Color(0xFF7FC58A)
                      : const Color(0xFFE9DDC6),
                  letterSpacing: 0.5,
                ),
              ),
            ),

            if (!_isSuccess && widget.showSimulationButton) ...[
              const SizedBox(height: 30),
              _buildSimulationButton(),
            ],

            if (_isSuccess) ...[
              const SizedBox(height: 28),
              _buildSuccessReward(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRipple({
    required double progress,
    required Color color,
    required double maxScale,
  }) {
    final scale = 0.65 + (progress * maxScale * 1.05);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity * 0.65,
        child: Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeal() {
    return AnimatedBuilder(
      animation: _sealController,
      builder: (context, child) {
        final successScale = _isSuccess
            ? 1.0 + (_sealController.value * 0.12)
            : 1.0;

        return Transform.scale(
          scale: successScale,
          child: Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF18120F).withValues(alpha: 0.78),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 外層咖啡色圓的黃色「虛線」框
                Positioned.fill(
                  child: CustomPaint(painter: _DashedSealBorderPainter()),
                ),

                // 中間紅色圓形，這個保持原本設定
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSuccess
                        ? const Color(0xFF287A4A)
                        : AppColors.primary,
                    border: Border.all(
                      color: const Color(0xFFD8AF58),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSuccess
                            ? Icons.verified_rounded
                            : Icons.workspace_premium_rounded,
                        size: 42,
                        color: const Color(0xFFE9DDC6),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _isSuccess ? '已解鎖' : '等待中',
                        style: AppTextStyles.microBold.copyWith(
                          color: const Color(0xFFE9DDC6),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimulationButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _simulateNfcSuccess,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFD8AF58).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFD8AF58).withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isProcessing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFD8AF58),
                  ),
                ),
              Text(
                _isProcessing ? '正在驗證 NFC……' : '點擊開始偵測',
                style: AppTextStyles.captionBold.copyWith(
                  color: const Color(0xFFE9DDC6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessReward() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7FC58A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7FC58A).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: Color(0xFFD8AF58),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '驗證成功後將前往彌封紙捲',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFFE9DDC6),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Text(
        '請確認手機 NFC 功能已開啟，並靠近實體感應標記',
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(
          color: const Color(0xFF8B837B),
          height: 1.5,
        ),
      ),
    );
  }
}

class _DashedSealBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final radius = size.width / 2 - 2;

    final paint = Paint()
      ..color = AppColors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const dashLength = 0.10;
    const gapLength = 0.08;

    double angle = 0;

    while (angle < math.pi * 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dashLength,
        false,
        paint,
      );

      angle += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _NfcBackground extends StatelessWidget {
  const _NfcBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _NfcBackgroundPainter());
  }
}

class _NfcBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final backgroundPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [Color(0xFF3D2A1F), Color(0xFF241710)],
      ).createShader(rect);

    canvas.drawRect(rect, backgroundPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFD8AF58).withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height);

    for (double radius = 90; radius < maxRadius; radius += 48) {
      canvas.drawCircle(center, radius, linePaint);
    }

    final crossPaint = Paint()
      ..color = const Color(0xFFE9DDC6).withValues(alpha: 0.025)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      crossPaint,
    );

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
