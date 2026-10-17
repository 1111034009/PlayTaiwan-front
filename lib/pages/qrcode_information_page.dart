import 'dart:ui' as ui;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

Map<String, dynamic> _asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const [];
}

String _str(dynamic value) {
  return value == null ? '' : value.toString().trim();
}

String _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = _str(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _formatDate(dynamic value) {
  final date = DateTime.tryParse(_str(value));
  if (date == null) return '';

  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year} / $month / $day';
}

class NfcInformationPage extends StatefulWidget {
  const NfcInformationPage({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  State<NfcInformationPage> createState() => _NfcInformationPageState();
}

class _NfcInformationPageState extends State<NfcInformationPage> {
  bool _savedCoupon = false;

  final GlobalKey _couponKey = GlobalKey();

  late final Map<String, dynamic> _coupon = _asMap(widget.result['coupon']);
  late final Map<String, dynamic> _place = _asMap(
    widget.result['merchant_place'],
  );
  late final Map<String, dynamic> _override = _asMap(
    _place['merchant_override'],
  );

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
  static const double _dialogMaxWidth = 420;

  bool get _hasCoupon => _coupon.isNotEmpty;

  String get _placeName {
    final name = _firstNonEmpty([_override['name'], _place['gov_name']]);
    return name.isEmpty ? '店家資訊' : name;
  }

  String get _placeArea => '${_str(_place['city'])}${_str(_place['town'])}';

  String get _description =>
      _firstNonEmpty([_override['description'], _place['gov_description']]);

  String get _address =>
      _firstNonEmpty([_override['address'], _place['gov_address']]);

  String get _phone => _str(_place['gov_phone']);

  String get _categories => _joinList(_place['categories'], '  ·  ');

  String get _hours => _joinList(_place['operating_hours'], '\n');

  String get _imageUrl {
    final String direct = _firstNonEmpty([
      _override['image_url'],
      _place['image_url'],
      widget.result['image_url'],
    ]);

    if (direct.startsWith('http')) return direct;

    for (final item in _asList(_place['images'])) {
      final url = item is Map ? _str(item['url']) : _str(item);
      if (url.startsWith('http')) return url;
    }
    return '';
  }

  String get _couponCode {
    final code = _str(_coupon['coupon_code']);
    return code.isEmpty ? '—' : code;
  }

  String get _couponId => _str(_coupon['coupon_id']);
  String get _couponTitle {
    final name = _str(_coupon['coupon_name']);
    return name.isEmpty ? '商圈專屬優惠券' : name;
  }

  String get _discountText {
    final value = _coupon['discount_value'];
    if (value is! num) return '';

    final shown = value == value.truncate() ? value.toInt() : value;
    return _str(_coupon['discount_type']) == 'percent'
        ? '$shown% 折扣'
        : '折抵 $shown 元';
  }

  String get _couponSubtitle =>
      _discountText.isEmpty ? '★專屬優惠★' : '★憑券享 $_discountText★';

  String get _couponScope {
    final commodity = _str(_coupon['discount_commodity']);
    return commodity.isEmpty ? '恕不與其他優惠併用' : '適用商品：$commodity (恕不與其他優惠併用)';
  }

  String get _couponValidity {
    final from = _formatDate(_coupon['valid_from']);
    final to = _formatDate(_coupon['valid_to']);

    if (to.isEmpty) return '';
    return from.isEmpty || from == to ? '有效期限：$to 止' : '有效期限：$from ~ $to';
  }

  String _joinList(dynamic value, String separator) {
    return _asList(
      value,
    ).map(_str).where((text) => text.isNotEmpty).join(separator);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showCouponDialog();
    });
  }

  Future<void> _showCouponDialog() async {
    if (!_hasCoupon) return;

    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
            child: _buildCouponDialog(),
          ),
        );
      },
    );
  }

  void _closeCoupon() {
    Navigator.of(context).pop();
  }

  void _showSnack(IconData icon, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Row(
          children: [
            Icon(icon, color: accentGold, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.captionBold.copyWith(color: paperLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCoupon() async {
    try {
      final boundaryContext = _couponKey.currentContext;

      if (boundaryContext == null) {
        _showSnack(Icons.error_outline_rounded, '優惠券尚未準備完成');
        return;
      }

      final renderObject = boundaryContext.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        _showSnack(Icons.error_outline_rounded, '無法取得優惠券畫面');
        return;
      }

      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) {
        throw StateError('無法產生優惠券圖片');
      }

      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      await Gal.putImageBytes(
        data.buffer.asUint8List(),
        name: 'coupon_$_couponCode',
      );

      _showSnack(Icons.download_done_rounded, '優惠券完整圖片已下載');
    } catch (_) {
      _showSnack(Icons.error_outline_rounded, '下載失敗，請確認相簿權限');
    }
  }

  void _saveCoupon() {
    setState(() {
      _savedCoupon = true;
    });

    Navigator.of(context).pop();

    _showSnack(Icons.confirmation_number_rounded, '已存入錢包，使用請前往錢包');
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
          if (_hasCoupon) ...[
            const SizedBox(height: 16),
            _buildCouponReminder(),
          ],
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
            _placeName,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              color: textDark,
              letterSpacing: 2.5,
            ),
          ),
          if (_placeArea.isNotEmpty)
            Text(
              _placeArea,
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

  Widget _buildImageFallback() {
    return Container(
      color: paperDark,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: textLight,
        size: 34,
      ),
    );
  }

  Widget _buildPhotoSection() {
    final imageUrl = _imageUrl;

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
              child: imageUrl.isEmpty
                  ? _buildImageFallback()
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildImageFallback(),
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
    final rows = [
      (Icons.category_rounded, '類型', _categories),
      (Icons.location_on_rounded, '地址', _address),
      (Icons.phone_rounded, '電話', _phone),
      (Icons.schedule_rounded, '營業時間', _hours),
    ].where((row) => row.$3.isNotEmpty).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: paperLight.withValues(alpha: 0.9),
        border: Border.all(color: borderBrass),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) _buildDashedDivider(),
            _buildInfoRow(rows[i].$1, rows[i].$2, rows[i].$3),
          ],
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
            _placeName,
            style: AppTextStyles.captionBold.copyWith(color: stampRed),
          ),
          const SizedBox(height: 6),
          Text(
            _description.isEmpty ? '暫無店家介紹' : _description,
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
              RepaintBoundary(
                key: _couponKey,
                child: Container(
                  color: paperLight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCouponHeader(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: _buildCouponCard(),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCouponButton(
                        icon: Icons.download_rounded,
                        label: '下載優惠券',
                        backgroundColor: paperDark,
                        foregroundColor: textDark,
                        onTap: _downloadCoupon,
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
            _couponSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallMedium.copyWith(
              color: const Color(0xFFFFE3A2),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _couponTitle,
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
    return Container(
      color: paperLight,
      padding: const EdgeInsets.all(12),
      child: CustomPaint(
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
                _couponCode,
                style: AppTextStyles.displayMedium.copyWith(
                  color: stampRed,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              _buildBarcode(),
              const SizedBox(height: 12),
              Text(
                _couponScope,
                textAlign: TextAlign.center,
                style: AppTextStyles.microLabelWide.copyWith(
                  color: textLight,
                  height: 1.5,
                ),
              ),
              if (_couponValidity.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  _couponValidity,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.microLabelWide.copyWith(
                    color: textLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarcode() {
    if (_couponId.isEmpty) {
      return Container(
        width: 160,
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderBrass),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            '缺少 coupon_id\n無法產生 QR Code',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderBrass.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: QrImageView(
        data: _couponId,
        version: QrVersions.auto,
        size: 160,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
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
