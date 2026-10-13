import 'package:flutter/material.dart';

import 'merchant_video_page.dart';
import '../api/merchant_vlog_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../block/merchant_progress_dialog.dart';

const Color _itemColor = AppColors.paper;
const Color _darkText = AppColors.textPrimary;
const Color _red = AppColors.primaryDark;
const Color _paperColor = AppColors.merchantPaper;

Future<void> openMerchantFile(BuildContext context, MerchantFile file) async {
  final id = file.id;

  if (id == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '此檔案缺少編號，無法開啟',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: _paperColor),
          ),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    return;
  }

  if (file.isProcessing) {
    final result = await showVideoProgressDialog(
      context,
      mmId: id,
      title: file.title,
    );

    if (result != VideoProgressResult.completed || !context.mounted) return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MerchantVideoPage(mmId: id)),
  );
}

class MerchantFileItem extends StatefulWidget {
  static const double height = 46;

  final MerchantFile file;
  final VoidCallback onTap;

  const MerchantFileItem({super.key, required this.file, required this.onTap});

  @override
  State<MerchantFileItem> createState() => _MerchantFileItemState();
}

class _MerchantFileItemState extends State<MerchantFileItem> {
  bool pressing = false;

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) {
      return value.isEmpty ? '無更新日期' : value;
    }

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year.$month.$day';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? 0.98 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          height: MerchantFileItem.height,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _itemColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _darkText, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.file.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionBold
                      .copyWith(color: Colors.black)
                      .copyWith(height: 1.25),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(widget.file.updatedAt),
                style: AppTextStyles.captionBold.copyWith(
                  color: Colors.black.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 6),
              _StatusIcon(processing: widget.file.isProcessing),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool processing;

  const _StatusIcon({required this.processing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _red,
        border: Border.all(color: _darkText, width: 1.2),
      ),
      child: processing
          ? const Padding(
              padding: EdgeInsets.all(5),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _paperColor,
              ),
            )
          : const Icon(Icons.play_arrow_rounded, size: 18, color: _paperColor),
    );
  }
}
