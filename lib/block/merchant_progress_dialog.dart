import 'dart:async';

import 'package:flutter/material.dart';

import '../api/merchant_vlog_api.dart';
import '../api/video_check.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const Color _paperColor = AppColors.merchantPaper;
const Color _darkText = AppColors.textPrimary;
const Color _progressTrack = AppColors.paper;
const Color _progressColor = Color(0xFFC7381E);
const Color _buttonColor = AppColors.primaryAccent;
const Color _black = Colors.black;

enum VideoProgressResult { completed, failed, background }

Future<VideoProgressResult> showVideoProgressDialog(
  BuildContext context, {
  required int mmId,
  String title = '',
}) async {
  final result = await showDialog<VideoProgressResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color.fromARGB(199, 0, 0, 0),
    builder: (_) => _VideoProgressDialog(mmId: mmId),
  );

  final value = result ?? VideoProgressResult.background;

  if (value == VideoProgressResult.background) {
    VideoCheck.watch(mmId, title: title);
  }

  return value;
}

class _VideoProgressDialog extends StatefulWidget {
  final int mmId;

  const _VideoProgressDialog({required this.mmId});

  @override
  State<_VideoProgressDialog> createState() => _VideoProgressDialogState();
}

class _VideoProgressDialogState extends State<_VideoProgressDialog>
    with SingleTickerProviderStateMixin {
  static const Duration _fakeDuration = Duration(seconds: 20);
  static const double _holdValue = 0.99;

  late final AnimationController _controller;
  String? _failedMessage;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this)
      ..animateTo(_holdValue, duration: _fakeDuration, curve: Curves.easeOut);

    _poll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final deadline = DateTime.now().add(const Duration(minutes: 15));

    while (mounted) {
      try {
        final status = await MerchantVlogApi.fetchStatus(widget.mmId);

        if (!mounted) return;

        if (status.isCompleted) {
          await _complete();
          return;
        }

        if (status.isFailed) {
          _fail(status.errorMessage);
          return;
        }
      } catch (_) {}

      if (!mounted) return;

      if (DateTime.now().isAfter(deadline)) {
        Navigator.pop(context, VideoProgressResult.background);
        return;
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _complete() async {
    setState(() => _finishing = true);

    await _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeIn,
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (mounted) Navigator.pop(context, VideoProgressResult.completed);
  }

  void _fail(String message) {
    _controller.stop();

    setState(() {
      _failedMessage = message.isEmpty ? '影片生成失敗，請重新嘗試' : message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failed = _failedMessage;

    return Dialog(
      backgroundColor: _paperColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: const BorderSide(color: _black, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: failed == null ? _buildProgress() : _buildFailed(failed),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '影片生成中',
          style: AppTextStyles.sectionTitle.copyWith(color: _darkText),
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final percent = (_controller.value * 100).round();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: AppTextStyles.title.copyWith(color: _progressColor),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 16,
                  child: CustomPaint(
                    painter: _ProgressBarPainter(progress: _controller.value),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          '正在合成影片，完成後會自動跳轉',
          textAlign: TextAlign.center,
          style: AppTextStyles.captionBold.copyWith(color: _darkText),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finishing
              ? null
              : () => Navigator.pop(context, VideoProgressResult.background),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              '背景處理',
              style: AppTextStyles.captionBold.copyWith(
                color: _progressColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailed(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '生成失敗',
          style: AppTextStyles.sectionTitle.copyWith(color: _darkText),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.captionBold
              .copyWith(color: _darkText)
              .copyWith(height: 1.5),
        ),
        const SizedBox(height: 16),
        _DialogButton(
          text: '關閉',
          onTap: () => Navigator.pop(context, VideoProgressResult.failed),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DialogButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _buttonColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _black, width: 1.2),
          boxShadow: const [
            BoxShadow(color: _darkText, offset: Offset(0, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          text,
          style: AppTextStyles.subtitle.copyWith(color: _paperColor),
        ),
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;

  const _ProgressBarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );

    canvas.drawRRect(outer, Paint()..color = _progressTrack);

    final double width = size.width * progress;

    if (width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width, size.height),
          const Radius.circular(8),
        ),
        Paint()..color = _progressColor,
      );
    }

    canvas.drawRRect(
      outer,
      Paint()
        ..color = _black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
