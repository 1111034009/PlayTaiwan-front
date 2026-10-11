import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

import 'qrcode_information_page.dart';

class _QrScanException implements Exception {
  const _QrScanException(this.message);

  final String message;
}

class StoryNfcPage extends StatefulWidget {
  const StoryNfcPage({super.key});

  @override
  State<StoryNfcPage> createState() => _StoryNfcPageState();
}

class _StoryNfcPageState extends State<StoryNfcPage>
    with TickerProviderStateMixin {
  static const String _apiBase =
      'https://backend.angelalala.com/api/qrcode/scan';

  late final AnimationController _rippleController;
  late final AnimationController _sealController;
  late final MobileScannerController _scannerController;

  bool _isSuccess = false;
  bool _isProcessing = false;
  String? _errorMessage;

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

    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _sealController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isSuccess) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue?.trim();

    if (rawValue == null || rawValue.isEmpty) return;

    _handleScan(rawValue);
  }

  String _extractQrUid(String rawValue) {
    final match = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ).firstMatch(rawValue);

    return match?.group(0) ?? rawValue;
  }

  Future<Map<String, dynamic>> _fetchQrResult(String qrUid) async {
    final token = AppSession.token?.trim();

    if (token == null || token.isEmpty) {
      throw const _QrScanException('登入狀態已失效，請重新登入後再掃描');
    }

    final response = await http
        .get(
          Uri.parse('$_apiBase/$qrUid'),
          headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(utf8.decode(response.bodyBytes));

    if (body is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        body['isSuccess'] != true ||
        body['Result'] is! Map) {
      final message = body is Map ? body['message']?.toString() : null;
      throw _QrScanException(message ?? 'QRcode 驗證失敗');
    }

    return Map<String, dynamic>.from(body['Result'] as Map);
  }

  Future<void> _handleScan(String rawValue) async {
    if (_isProcessing || _isSuccess) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final qrUid = _extractQrUid(rawValue);
      final result = await _fetchQrResult(qrUid);

      if (!mounted) return;

      setState(() {
        _isSuccess = true;
        _isProcessing = false;
      });

      _sealController.forward(from: 0);

      await Future<void>.delayed(const Duration(milliseconds: 1400));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => NfcInformationPage(result: result)),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error is _QrScanException
            ? error.message
            : '連線失敗，請稍後再試';
      });

      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _cancel() {
    if (_isProcessing) return;

    Navigator.of(context).pop(false);
  }

  String get _statusText {
    if (_isSuccess) return 'QRcode 解鎖成功！';
    if (_errorMessage != null) return _errorMessage!;
    if (_isProcessing) return '正在驗證 QRcode……';

    return '請將鏡頭對準 QRcode';
  }

  Color get _statusColor {
    if (_isSuccess) return const Color(0xFF7FC58A);
    if (_errorMessage != null) return const Color(0xFFE57373);

    return const Color(0xFFE9DDC6);
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
            Icons.qr_code_scanner_rounded,
            size: 18,
            color: const Color(0xFFE9DDC6).withValues(alpha: 0.75),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'QRcode驗證中',
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
                  width: 350,
                  height: 350,
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
                _statusText,
                key: ValueKey<String>(_statusText),
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(
                  color: _statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
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
          width: 270,
          height: 270,
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
            width: 230,
            height: 230,
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
                Positioned.fill(
                  child: CustomPaint(painter: _DashedSealBorderPainter()),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 200,
                  height: 200,
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
                  child: ClipOval(
                    child: _isSuccess ? _buildUnlocked() : _buildScanner(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnlocked() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.verified_rounded, size: 42, color: Color(0xFFE9DDC6)),
        const SizedBox(height: 5),
        Text(
          '已解鎖',
          style: AppTextStyles.microBold.copyWith(
            color: const Color(0xFFE9DDC6),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          fit: BoxFit.cover,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            return Container(
              color: const Color(0xFF241710),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: Color(0xFFE9DDC6),
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '相機無法啟動',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: const Color(0xFFE9DDC6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: const Color(0xFFD8AF58),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_isProcessing && _errorMessage == null)
          const ColoredBox(
            color: Colors.black54,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFD8AF58),
                ),
              ),
            ),
          ),
      ],
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
        '請確認已允許相機權限，並將 QRcode 置於圓形範圍內',
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
