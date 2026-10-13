import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../api/postcard_api.dart';
import '../block/navigationbar.dart';
import 'story_end_page.dart';
import '../core/app_text_styles.dart';
import '../core/app_colors.dart';

const Color _backgroundColor = AppColors.storyBackground;
const Color _lightText = AppColors.paper;
const Color _white80 = Color(0xCCFFFFFF);

const Color _secondaryBorder = AppColors.paper;
const Color _secondaryCenter = Color(0xFF724E4E);
const Color _secondaryOuter = AppColors.pastBackground;

const Color _primaryBorder = AppColors.primaryDark;
const Color _primaryCenter = AppColors.primaryLight;
const Color _primaryOuter = AppColors.primary;

class StoryPostcardPage extends StatefulWidget {
  final VoidCallback? onNext;

  /// 地圖頁破關後帶進來的：要做成明信片的照片（玩家在拍照任務交的，或當場拍的）、這一關的景點名稱、劇本和節點代號。
  /// 沒給照片就用下面原本寫死的測試資料
  final Uint8List? imageBytes;
  final String imageName;
  final String? spotName;
  final int? storyId;
  final int? nodeId;

  const StoryPostcardPage({
    super.key,
    this.onNext,
    this.imageBytes,
    this.imageName = 'photo.jpg',
    this.spotName,
    this.storyId,
    this.nodeId,
  });

  @override
  State<StoryPostcardPage> createState() => _StoryPostcardPageState();
}

class _StoryPostcardPageState extends State<StoryPostcardPage>
    with SingleTickerProviderStateMixin {
  static const double designWidth = 430;
  static const double designHeight = 760;

  int currentIndex = 1;

  final PostcardApi _postcardApi = PostcardApi();

  late final AnimationController _progressController;

  double _progress = 0.1;

  Uint8List? _postcardImage;

  String? _postcardError;

  String? _taskId;

  bool _isGenerating = true;

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

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    _progressController.addListener(() {
      if (!mounted || !_isGenerating) return;

      setState(() {
        _progress = 0.1 + (_progressController.value * 0.82);
      });
    });

    _startGeneratePostcard();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startGeneratePostcard() async {
    const String imagePath =
        r'C:\Users\owner\nutc\Competition\InnoServe\PLAYTAIWAN\front\img\test\tset.webp';

    const String spotName = '孔廟';
    const String userPrompt = '復古水墨風';
    const String storyId = 'story_001';
    const bool isNightEdition = false;

    try {
      if (mounted) {
        setState(() {
          _isGenerating = true;
          _progress = 0.1;
          _postcardError = null;
          _postcardImage = null;
          _taskId = null;
        });
      }

      _progressController.forward(from: 0);

      final AiPostcardResult result = await _postcardApi.createAiPostcard(
        imagePath: imagePath,
        imageBytes: widget.imageBytes,
        imageName: widget.imageName,
        spotName: widget.spotName ?? spotName,
        userPrompt: userPrompt,
        storyId: widget.storyId?.toString() ?? storyId,
        nodeId: widget.nodeId?.toString() ?? '',
        isNightEdition: isNightEdition,
      );

      _taskId = result.taskId;

      Uint8List? imageBytes;

      for (int i = 0; i < 60; i++) {
        imageBytes = await _postcardApi.downloadAiPostcard(result.downloadUrl);

        if (imageBytes != null && imageBytes.isNotEmpty) {
          break;
        }

        await Future.delayed(const Duration(seconds: 2));
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('AI 明信片生成逾時，請稍後再試。');
      }

      if (!mounted) {
        return;
      }

      _progressController.stop();

      setState(() {
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) {
        return;
      }

      setState(() {
        _postcardImage = imageBytes;
        _isGenerating = false;
        _postcardError = null;
      });
    } catch (e) {
      _progressController.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
        _postcardError = e.toString();
      });
    }
  }

  Future<void> _printPostcard() async {
    if (_isGenerating) {
      showMessage('明信片尚未生成完成');
      return;
    }

    if (_postcardImage == null) {
      showMessage('目前沒有可列印的明信片');
      return;
    }

    final String postcardId = _taskId?.trim() ?? '';

    if (postcardId.isEmpty) {
      showMessage('找不到明信片 ID');
      return;
    }

    _showPrintLoadingDialog();

    try {
      final Map<String, dynamic> printResult = await _postcardApi.printPostcard(
        postcardId: postcardId,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      await _showPrintDialog(printResult);
    } catch (e) {
      debugPrint('取得 ibon 取件碼失敗：$e');

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      showMessage('取得 ibon 取件碼失敗');
    }
  }

  Future<void> _showPrintLoadingDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: _PrintLoadingContent(),
        );
      },
    );
  }

  Future<void> _showPrintDialog(Map<String, dynamic> result) async {
    final String pickupCode = result['ibon_pickup_code']?.toString() ?? '';

    final String deadline = result['deadline']?.toString() ?? '';

    final String qrCodeBase64 = result['qrcode_base64']?.toString() ?? '';

    Uint8List? qrCodeBytes;

    if (qrCodeBase64.isNotEmpty) {
      try {
        String base64Data = qrCodeBase64;

        if (base64Data.contains(',')) {
          base64Data = base64Data.split(',').last;
        }

        qrCodeBytes = base64Decode(base64Data);
      } catch (_) {
        qrCodeBytes = null;
      }
    }

    String formattedDeadline = deadline;

    if (deadline.isNotEmpty) {
      try {
        final DateTime dateTime = DateTime.parse(deadline).toLocal();

        formattedDeadline =
            '${dateTime.year}/'
            '${dateTime.month.toString().padLeft(2, '0')}/'
            '${dateTime.day.toString().padLeft(2, '0')} '
            '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            width: 360,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.90,
            ),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 30,
                  spreadRadius: 1,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ibon 列印資訊',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (formattedDeadline.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.secondaryRed.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryRed.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              size: 17,
                              color: AppColors.secondaryRed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '列印期限',
                                  style: AppTextStyles.microLabel.copyWith(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedDeadline,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (qrCodeBytes != null) ...[
                    Text(
                      '掃描 QR Code',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '至 ibon 機台掃描即可列印',
                      style: AppTextStyles.microLabel.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 220,
                      height: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.10),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        qrCodeBytes,
                        width: 230,
                        height: 230,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 220,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            bool hasAccess = await Gal.hasAccess();

                            if (!hasAccess) {
                              hasAccess = await Gal.requestAccess();
                            }

                            if (!hasAccess) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text('沒有相簿權限，無法儲存 QR Code'),
                                  ),
                                );
                              }
                              return;
                            }

                            await Gal.putImageBytes(
                              qrCodeBytes!,
                              album: '回憶明信片',
                              name:
                                  'ibon_qrcode_${DateTime.now().millisecondsSinceEpoch}.png',
                            );

                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('QR Code 已成功儲存到相簿'),
                                ),
                              );
                            }
                          } catch (_) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('QR Code 儲存失敗')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('下載 QR Code'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: 220,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'QR Code 無法載入',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '列印取件碼',
                      style: AppTextStyles.microLabel.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.045),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickupCode.isEmpty ? '—' : pickupCode,
                            style: AppTextStyles.heading.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: pickupCode.isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: pickupCode),
                                  );

                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(
                                      dialogContext,
                                    ).showSnackBar(
                                      const SnackBar(content: Text('取件碼已複製')),
                                    );
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.copy_rounded,
                              size: 17,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '關閉',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void goNext() {
    if (widget.onNext != null) {
      widget.onNext!();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StoryEndPage()),
    );
  }

  void goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold
                .copyWith(color: Colors.white)
                .copyWith(height: 1.2),
          ),
          backgroundColor: _backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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
                Positioned(
                  left: 0,
                  right: 0,
                  top: 90,
                  child: Center(child: _OutlinedTitle(text: '謎題解開')),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 132,
                  child: Center(
                    child: Text(
                      '獲得專屬記憶明信片',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: _white80)
                          .copyWith(height: 1.2, letterSpacing: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  top: 190,
                  width: 418,
                  height: 278,
                  child: _PostcardDisplay(
                    isGenerating: _isGenerating,
                    progress: _progress,
                    imageBytes: _postcardImage,
                    errorMessage: _postcardError,
                  ),
                ),
                Positioned(
                  left: 22,
                  top: 478,
                  width: 184,
                  height: 52,
                  child: _SecondaryButton(text: '實體列印', onTap: _printPostcard),
                ),
                Positioned(
                  left: 224,
                  top: 478,
                  width: 184,
                  height: 52,
                  child: _SecondaryButton(
                    text: '分享',
                    onTap: () {
                      showMessage('已準備分享功能');
                    },
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: 552,
                  height: 53,
                  child: _PrimaryButton(text: '前往下一站', onTap: goNext),
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

class _PrintLoadingContent extends StatefulWidget {
  const _PrintLoadingContent();

  @override
  State<_PrintLoadingContent> createState() => _PrintLoadingContentState();
}

class _PrintLoadingContentState extends State<_PrintLoadingContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 55),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 25, spreadRadius: 2),
        ],
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final double progress = (controller.value * 0.95).clamp(0.0, 0.95);

          final int percentage = (progress * 100).round();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '正在準備列印',
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.secondaryRed,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$percentage%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
          style: AppTextStyles.heroDisplay
              .copyWith(color: _lightText)
              .copyWith(
                height: 1.0,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3.2
                  ..color = Colors.black,
              ),
        ),
        Text(
          text,
          style: AppTextStyles.heroDisplay
              .copyWith(color: Colors.white)
              .copyWith(height: 1.0),
        ),
      ],
    );
  }
}

class _PostcardDisplay extends StatelessWidget {
  final bool isGenerating;
  final double progress;
  final Uint8List? imageBytes;
  final String? errorMessage;

  const _PostcardDisplay({
    required this.isGenerating,
    required this.progress,
    required this.imageBytes,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [
          BoxShadow(
            color: Color(0x70000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }

    if (errorMessage != null) {
      return _buildError();
    }

    return _buildGenerating();
  }

  Widget _buildGenerating() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              '正在繪製你的專屬明信片',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle
                  .copyWith(color: const Color(0xFF6D2A1D))
                  .copyWith(height: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              '臺南孔廟',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold
                  .copyWith(color: const Color(0xFF724E4E))
                  .copyWith(height: 1.2),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE6D9C8),
                valueColor: const AlwaysStoppedAnimation<Color>(_primaryOuter),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '${(progress * 100).round()}%',
              style: AppTextStyles.bodySmallBold.copyWith(
                color: const Color(0xFF6D2A1D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 42,
              color: Color(0xFF6D2A1D),
            ),
            const SizedBox(height: 14),
            Text(
              '明信片生成失敗',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(
                color: const Color(0xFF6D2A1D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '未知錯誤',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF724E4E),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _SecondaryButton({required this.text, required this.onTap});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
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
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutBack,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _secondaryBorder, width: 2),
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_secondaryCenter, _secondaryCenter, _secondaryOuter],
                stops: [0.0, 0.45, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle
                  .copyWith(color: _lightText)
                  .copyWith(height: 1.1, letterSpacing: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing
        ? 0.96
        : hovering
        ? 1.06
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
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutBack,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: _primaryBorder, width: 2),
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_primaryCenter, _primaryCenter, _primaryOuter],
                stops: [0.0, 0.45, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMediumBold
                  .copyWith(color: _lightText)
                  .copyWith(height: 1.1, letterSpacing: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
