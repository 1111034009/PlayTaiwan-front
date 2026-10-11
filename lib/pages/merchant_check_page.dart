import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'merchant_home_page.dart';
import '../block/merchant_progress_dialog.dart';
import 'merchant_video_page.dart';
import '../api/merchant_vlog_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _paperColor = AppColors.paper;
const Color _darkText = AppColors.textPrimary;
const Color _lineColor = AppColors.storyBackground;
const Color _hintColor = Color(0xFF7F756D);
const Color _red = AppColors.deepRed;
const Color _tagRed = AppColors.primaryAccent;
const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;
const Color _black = Colors.black;

class MerchantCheckPage extends StatefulWidget {
  final VlogPreview preview;

  const MerchantCheckPage({super.key, required this.preview});

  @override
  State<MerchantCheckPage> createState() => _MerchantCheckPageState();
}

class _MerchantCheckPageState extends State<MerchantCheckPage> {
  late final TextEditingController _scriptController;
  late final TextEditingController _captionController;
  final TextEditingController _tagController = TextEditingController();
  late final List<String> _hashtags;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _scriptController = TextEditingController(text: widget.preview.script);
    _captionController = TextEditingController(text: widget.preview.caption);
    _hashtags = List<String>.from(widget.preview.hashtags);

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

  @override
  void dispose() {
    _scriptController.dispose();
    _captionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
          ),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _addTag() {
    final raw = _tagController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return;

    final tag = raw.startsWith('#') ? raw : '#$raw';

    if (tag.length > 1 && !_hashtags.contains(tag)) {
      setState(() => _hashtags.add(tag));
    }

    _tagController.clear();
  }

  Future<void> _confirm() async {
    if (_submitting) return;

    final script = _scriptController.text.trim();

    if (script.isEmpty) {
      _showMessage('旁白不可為空');
      return;
    }

    _addTag();
    setState(() => _submitting = true);

    try {
      final task = await MerchantVlogApi.createFinal(
        mmId: widget.preview.mmId,
        finalScript: script,
        caption: _captionController.text.trim(),
        hashtags: _hashtags,
      );

      if (!mounted) return;

      final result = await showVideoProgressDialog(
        context,
        mmId: task.mmId,
        title: widget.preview.storeName,
      );

      if (!mounted) return;

      if (result == VideoProgressResult.failed) {
        setState(() => _submitting = false);
        return;
      }

      final navigator = Navigator.of(context);

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MerchantHomePage()),
        (route) => false,
      );

      if (result == VideoProgressResult.completed) {
        navigator.push(
          MaterialPageRoute(builder: (_) => MerchantVideoPage(mmId: task.mmId)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;

    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _submitting ? null : () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      '<< 返回編輯',
                      style: AppTextStyles.bodySmallBold
                          .copyWith(color: const Color(0xFFFAF7F1))
                          .copyWith(
                            shadows: const [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(1.2, 1.5),
                                blurRadius: 1.5,
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: _PageTitle(text: '確認內容')),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '確認或修改後，開始合成影音',
                  style: AppTextStyles.bodyEmphasisBold
                      .copyWith(color: Colors.white)
                      .copyWith(
                        height: 1.05,
                        shadows: const [
                          Shadow(
                            color: Color(0x66000000),
                            offset: Offset(1.2, 1.5),
                            blurRadius: 1.5,
                          ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: BoxDecoration(
                  color: _paperColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preview.storeName.isNotEmpty)
                      Text(
                        preview.storeName,
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: _darkText,
                        ),
                      ),
                    if (preview.address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        preview.address,
                        style: AppTextStyles.captionBold.copyWith(
                          color: _hintColor,
                        ),
                      ),
                    ],
                    if (preview.toneName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '語氣：${preview.toneName}',
                        style: AppTextStyles.captionBold.copyWith(
                          color: _hintColor,
                        ),
                      ),
                    ],
                    if (preview.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: preview.imageUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              width: 88,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _lineColor),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Image.network(
                                preview.imageUrls[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: _hintColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const _SectionLabel('旁白草稿'),
                    const SizedBox(height: 4),
                    _EditBox(
                      controller: _scriptController,
                      minLines: 8,
                      hint: '請輸入旁白',
                    ),
                    const SizedBox(height: 14),
                    const _SectionLabel('推薦配文'),
                    const SizedBox(height: 4),
                    _EditBox(
                      controller: _captionController,
                      minLines: 4,
                      hint: '請輸入配文',
                    ),
                    const SizedBox(height: 14),
                    const _SectionLabel('推薦標籤'),
                    const SizedBox(height: 6),
                    if (_hashtags.isNotEmpty)
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final tag in _hashtags)
                            _Tag(
                              text: tag,
                              onRemove: () =>
                                  setState(() => _hashtags.remove(tag)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: _lineColor),
                            ),
                            child: TextField(
                              controller: _tagController,
                              maxLines: 1,
                              onSubmitted: (_) => _addTag(),
                              style: AppTextStyles.bodySmallMedium.copyWith(
                                color: _darkText,
                              ),
                              cursorColor: _red,
                              decoration: InputDecoration(
                                hintText: '新增標籤',
                                hintStyle: AppTextStyles.captionSmall.copyWith(
                                  color: _hintColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addTag,
                          child: Container(
                            width: 38,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _red,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: _buttonBorder,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: _paperColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _ActionButton(
                            text: '重新編輯',
                            primary: false,
                            enabled: !_submitting,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: _ActionButton(
                            text: '確認生成',
                            primary: true,
                            busy: _submitting,
                            enabled: !_submitting,
                            onTap: _confirm,
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
}

class _PageTitle extends StatelessWidget {
  final String text;

  const _PageTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('img/user_icon_line.png', width: 24, height: 24),
        const SizedBox(width: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              style: AppTextStyles.pageTitle
                  .copyWith(color: Colors.white)
                  .copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.6
                      ..color = _darkText,
                  ),
            ),
            Text(
              text,
              style: AppTextStyles.pageTitle.copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmallBold.copyWith(color: _darkText),
    );
  }
}

class _EditBox extends StatelessWidget {
  final TextEditingController controller;
  final int minLines;
  final String hint;

  const _EditBox({
    required this.controller,
    required this.minLines,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _lineColor),
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: AppTextStyles.bodySmallMedium
            .copyWith(color: _darkText)
            .copyWith(height: 1.42),
        cursorColor: _red,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.captionSmall.copyWith(color: _hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(10),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final VoidCallback onRemove;

  const _Tag({required this.text, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: _tagRed,
        border: Border.all(color: _black, width: 1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: _darkText, offset: Offset(0, 2), blurRadius: 0),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AppTextStyles.label
                .copyWith(color: AppColors.merchantPaper)
                .copyWith(height: 1),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 15,
              color: AppColors.merchantPaper,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String text;
  final bool primary;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.text,
    required this.primary,
    required this.onTap,
    this.busy = false,
    this.enabled = true,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final bool primary = widget.primary;

    return Opacity(
      opacity: widget.enabled || widget.busy ? 1 : 0.6,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: widget.enabled
            ? (_) => setState(() => _pressing = true)
            : null,
        onTapUp: widget.enabled
            ? (_) => setState(() => _pressing = false)
            : null,
        onTapCancel: () => setState(() => _pressing = false),
        child: AnimatedScale(
          scale: _pressing ? 0.96 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? null : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: primary ? _buttonBorder : _lineColor,
                width: 2,
              ),
              gradient: primary
                  ? const RadialGradient(
                      center: Alignment(-0.2, -0.2),
                      radius: 1.15,
                      colors: [_buttonCenter, _buttonCenter, _buttonOuter],
                      stops: [0.0, 0.45, 1.0],
                    )
                  : null,
              boxShadow: primary
                  ? const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: widget.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _paperColor,
                    ),
                  )
                : Text(
                    widget.text,
                    style: AppTextStyles.subtitle.copyWith(
                      color: primary ? _paperColor : _lineColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
