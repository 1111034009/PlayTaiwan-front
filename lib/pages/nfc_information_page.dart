import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class NfcInformationPage extends StatefulWidget {
  const NfcInformationPage({
    super.key,
    this.locationName = '做咖啡 hecho cafe & wine',
    this.sealName = 'NFC 御印',
    this.rewardText = '臺中做咖啡 hecho cafe & wine 專屬優惠券',
  });

  final String locationName;
  final String sealName;
  final String rewardText;

  @override
  State<NfcInformationPage> createState() => _NfcInformationPageState();
}

class _NfcInformationPageState extends State<NfcInformationPage> {
  bool _savedCoupon = false;

  static const Color paperBg = AppColors.warmPaper;
  static const Color paperLight = AppColors.merchantPaper;
  static const Color paperDark = AppColors.questionBackground;
  static const Color textDark = AppColors.textPrimary;
  static const Color textLight = AppColors.storyBackground;
  static const Color stampRed = AppColors.primary;
  static const Color accentGold = AppColors.progressTrack;
  static const Color accentBrass = AppColors.postcardLine;
  static const Color borderBrass = AppColors.postcard;

  static const double _dialogBorderWidth = 2;
  static const double _dialogRadius = 22;

  static const String couponCode = 'TN-CONF-8588';
  static const String couponTitle = '商圈專屬優惠券';
  static const String couponSubtitle = '★憑券享指定店家 85 折優惠★';
  static const String couponScope = '適用店家：勤美周邊合作店家 (恕不與其他優惠併用)';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showCouponDialog();
    });
  }

  Future<void> _showCouponDialog() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: _buildCouponDialog(),
        );
      },
    );
  }

  void _closeCoupon() {
    Navigator.of(context).pop();
  }

  void _copyCouponCode() {
    Clipboard.setData(const ClipboardData(text: couponCode));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: accentGold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已複製優惠碼：$couponCode',
                style: AppTextStyles.captionBold.copyWith(color: paperLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCoupon() {
    setState(() {
      _savedCoupon = true;
    });

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            const Icon(
              Icons.confirmation_number_rounded,
              color: accentGold,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '專屬優惠券已存入優惠包',
                style: AppTextStyles.captionBold.copyWith(color: paperLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paperBg,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _PaperTextureBackground()),
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildNewspaperContent()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        color: paperLight,
        border: Border(bottom: BorderSide(color: borderBrass, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.close_rounded, color: textDark),
        ),
      ),
    );
  }

  Widget _buildNewspaperContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNewspaperHeader(),
          const SizedBox(height: 14),
          _buildPhotoSection(),
          const SizedBox(height: 16),
          _buildInfoSection(),
          const SizedBox(height: 16),
          _buildDescriptionSection(),
          const SizedBox(height: 16),
          _buildCouponReminder(),
        ],
      ),
    );
  }

  Widget _buildNewspaperHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 11),
      decoration: BoxDecoration(
        color: paperLight.withValues(alpha: 0.88),
        border: Border.all(color: borderBrass, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Divider(color: accentBrass)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '地方商旅誌',
                  style: AppTextStyles.microBold.copyWith(
                    color: stampRed,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: accentBrass)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '做咖啡',
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              color: textDark,
              letterSpacing: 2.5,
            ),
          ),
          Text(
            'hecho cafe & wine',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: textLight,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      decoration: BoxDecoration(
        color: paperLight,
        border: Border.all(color: borderBrass),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.asset(
                'img/nfc_test.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: paperDark,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image_not_supported_outlined,
                          color: textLight,
                          size: 34,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'img/ngc_test.png',
                          style: AppTextStyles.micro.copyWith(color: textLight),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: borderBrass)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Text(
                  '店家實景',
                  style: AppTextStyles.micro.copyWith(
                    color: textLight,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: borderBrass)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: paperLight.withValues(alpha: 0.9),
        border: Border.all(color: borderBrass),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.category_rounded, '類型', '飲食  ·  早午餐'),
          _buildDashedDivider(),
          _buildInfoRow(Icons.location_on_rounded, '地址', '台中市西區美村路一段149巷12號'),
          _buildDashedDivider(),
          _buildInfoRow(Icons.phone_rounded, '電話', '04-2326-1649'),
          _buildDashedDivider(),
          _buildInfoRow(Icons.schedule_rounded, '營業時間', '每日 10:00–22:30'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: paperBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderBrass),
            ),
            child: Icon(icon, color: stampRed, size: 16),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                label,
                style: AppTextStyles.captionBold.copyWith(color: textLight),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                value,
                style: AppTextStyles.captionBold.copyWith(
                  color: textDark,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate((constraints.maxWidth / 7).floor(), (index) {
            return Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                color: index.isEven
                    ? borderBrass.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: paperLight.withValues(alpha: 0.82),
        border: Border.all(color: borderBrass.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 22, color: stampRed),
              const SizedBox(width: 8),
              Text(
                '店家小誌',
                style: AppTextStyles.bodyBold.copyWith(
                  color: textDark,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '做咖啡 hecho cafe & wine',
            style: AppTextStyles.captionBold.copyWith(color: stampRed),
          ),
          const SizedBox(height: 6),
          Text(
            '一處以咖啡與餐飲為主的生活空間，適合在城市漫遊途中稍作停留。',
            style: AppTextStyles.caption.copyWith(
              color: textDark,
              height: 1.75,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponReminder() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCouponDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: stampRed.withValues(alpha: 0.07),
            border: Border.all(color: stampRed.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: stampRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_activity_rounded,
                  color: accentGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _savedCoupon ? '優惠券已存入優惠包，觸碰查看。' : '觸碰查看優惠卷',
                  style: AppTextStyles.captionBold.copyWith(
                    color: textDark,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponDialog() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_dialogRadius),
        border: Border.all(color: borderBrass, width: _dialogBorderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 30,
            spreadRadius: 2,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(_dialogBorderWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_dialogRadius - _dialogBorderWidth),
        child: Container(
          color: paperLight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCouponHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  children: [
                    _buildCouponCard(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCouponButton(
                            icon: Icons.copy_rounded,
                            label: '複製優惠碼',
                            backgroundColor: paperDark,
                            foregroundColor: textDark,
                            onTap: _copyCouponCode,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCouponButton(
                            icon: _savedCoupon
                                ? Icons.check_circle_rounded
                                : Icons.wallet_rounded,
                            label: _savedCoupon ? '已存入優惠包' : '存入優惠包',
                            backgroundColor: stampRed,
                            foregroundColor: paperLight,
                            onTap: _savedCoupon ? _closeCoupon : _saveCoupon,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCouponHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: const BoxDecoration(
        color: stampRed,
        border: Border(bottom: BorderSide(color: Color(0x66D8AF58), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            couponSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallMedium.copyWith(
              color: const Color(0xFFFFE3A2),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            couponTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(
              color: paperLight,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard() {
    return CustomPaint(
      foregroundPainter: _DashedRectPainter(color: borderBrass, radius: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        decoration: BoxDecoration(
          color: paperBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '專屬折扣碼',
              style: AppTextStyles.bodySmallBold.copyWith(color: textLight),
            ),
            const SizedBox(height: 4),
            Text(
              couponCode,
              style: AppTextStyles.displayMedium.copyWith(
                color: stampRed,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 14),
            _buildBarcode(),
            const SizedBox(height: 12),
            Text(
              couponScope,
              textAlign: TextAlign.center,
              style: AppTextStyles.microLabelWide.copyWith(
                color: textLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '有效期限：2026 / 10 / 08 止',
              style: AppTextStyles.microLabelWide.copyWith(color: textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcode() {
    const bars = <double>[
      1,
      2,
      0.5,
      3,
      1,
      2,
      1.5,
      0.5,
      2,
      1,
      2.5,
      1,
      0.5,
      2,
      1,
    ];

    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: paperLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderBrass.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: bars.map((width) {
          return Container(
            width: width,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: textDark,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCouponButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foregroundColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.4,
    this.dashWidth = 6,
    this.dashSpace = 4,
    this.radius = 16,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rRect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.radius != radius;
  }
}

class _PaperTextureBackground extends StatelessWidget {
  const _PaperTextureBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PaperTexturePainter());
  }
}

class _PaperTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final backgroundPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.15,
        colors: [Color(0xFFF7F2E8), Color(0xFFE2D8BD)],
      ).createShader(rect);

    canvas.drawRect(rect, backgroundPaint);

    final linePaint = Paint()
      ..color = const Color(0x402E2118)
      ..strokeWidth = 0.35;

    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dotPaint = Paint()..color = const Color(0x183F2A1D);

    for (double y = 8; y < size.height; y += 23) {
      for (double x = 5; x < size.width; x += 27) {
        canvas.drawCircle(Offset(x, y), 0.55, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
