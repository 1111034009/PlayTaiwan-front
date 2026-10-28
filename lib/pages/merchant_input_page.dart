import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'merchant_check_page.dart';
import 'merchant_loading_page.dart';
import '../api/merchant_vlog_api.dart';
import '../core/app_colors.dart';
import '../core/app_notice.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _paperColor = AppColors.paper;
const Color _darkText = AppColors.textPrimary;
const Color _lineColor = AppColors.storyBackground;
const Color _hintColor = Color(0xFF7F756D);
const Color _red = AppColors.deepRed;
const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;
const Color _uploadBorder = AppColors.softBrown;

class _UploadItem {
  final String name;
  final String? path;

  const _UploadItem(this.name, this.path);
}

class MerchantInputPage extends StatefulWidget {
  final int? initialMmId;

  const MerchantInputPage({super.key, this.initialMmId});

  @override
  State<MerchantInputPage> createState() => _MerchantInputPageState();
}

class _MerchantInputPageState extends State<MerchantInputPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;
  static const int maxUploadFiles = 10;

  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController promotionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<VlogTone> tones = [];
  bool tonesLoading = true;
  String? tonesError;
  int? selectedToneId;

  final List<_UploadItem> uploadedFiles = [];
  int? _mmId;
  bool _generating = false;

  @override
  void initState() {
    super.initState();

    _mmId = widget.initialMmId;

    if (_mmId != null) {
      uploadedFiles.add(const _UploadItem('沿用原有素材', null));
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _loadTones();
  }

  @override
  void dispose() {
    shopNameController.dispose();
    promotionController.dispose();
    super.dispose();
  }

  Future<void> _loadTones() async {
    setState(() {
      tonesLoading = true;
      tonesError = null;
    });

    try {
      final result = await MerchantVlogApi.fetchTones();

      if (!mounted) return;

      setState(() {
        tones = result;
        tonesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        tonesLoading = false;
        tonesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    AppNotice.show(message);
  }

  Future<void> uploadFile() async {
    final remaining = maxUploadFiles - uploadedFiles.length;

    if (remaining <= 0) {
      showMessage('最多可以上傳 6 個素材');
      return;
    }

    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);

      if (picked.isEmpty || !mounted) return;

      if (picked.length > remaining) {
        showMessage('最多可以上傳 6 個素材');
      }

      setState(() {
        uploadedFiles.addAll(
          picked.take(remaining).map((f) => _UploadItem(f.name, f.path)),
        );
      });
    } catch (_) {
      showMessage('無法選取照片，請確認相簿權限');
    }
  }

  void removeFile(int index) {
    if (uploadedFiles[index].path == null) {
      showMessage('已上傳的照片無法移除');
      return;
    }

    setState(() => uploadedFiles.removeAt(index));
  }

  Future<void> generate() async {
    if (_generating) return;

    final promoText = promotionController.text.trim();

    if (promoText.isEmpty) {
      showMessage('請輸入推廣資訊');
      return;
    }

    if (selectedToneId == null) {
      showMessage('請選擇敘事語氣');
      return;
    }

    final newPaths = [
      for (final f in uploadedFiles)
        if (f.path != null) f.path!,
    ];

    if (_mmId == null && newPaths.isEmpty) {
      showMessage('請至少上傳一個素材');
      return;
    }

    final storeName = shopNameController.text;
    final toneId = selectedToneId;
    final mmId = _mmId;

    setState(() => _generating = true);

    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoLoadingPage(
          task: () => MerchantVlogApi.preview(
            mmId: mmId,
            storeName: storeName,
            ntId: toneId,
            promoText: promoText,
            imagePaths: newPaths,
          ),
        ),
      ),
    );

    if (!mounted) return;

    setState(() => _generating = false);

    if (result is VlogPreview) {
      setState(() {
        _mmId = result.mmId;
        uploadedFiles
          ..clear()
          ..addAll([
            for (int i = 0; i < result.imageUrls.length; i++)
              _UploadItem('已上傳照片 ${i + 1}', null),
          ]);
      });

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MerchantCheckPage(preview: result)),
      );
    } else if (result != null) {
      showMessage(result.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _buildToneRow() {
    if (tonesLoading) {
      return const SizedBox(
        height: 34,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _red),
          ),
        ),
      );
    }

    if (tonesError != null || tones.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _loadTones,
        child: SizedBox(
          height: 34,
          child: Center(
            child: Text(
              '語氣載入失敗，點擊重試',
              style: AppTextStyles.captionBold.copyWith(
                color: _red,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < tones.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: _ToneButton(
              text: tones[i].name,
              selected: selectedToneId == tones[i].id,
              onTap: () => setState(() => selectedToneId = tones[i].id),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _pageColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / designWidth;

          return Center(
            child: SizedBox(
              width: designWidth * scale,
              height: designHeight * scale,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: designWidth,
                  height: designHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: _pageColor),
                      ),
                      Positioned(
                        left: 23,
                        top: 10,
                        child: _BackButton(onTap: () => Navigator.pop(context)),
                      ),
                      Positioned(
                        top: 48,
                        left: 0,
                        width: designWidth,
                        child: Center(
                          child: _PageTitle(
                            text: '輸入資訊',
                            iconPath: 'img/user_icon_line.png',
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 85,
                        child: Center(
                          child: Text(
                            '輸入資訊，生成專屬推廣短影音',
                            textAlign: TextAlign.center,
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
                      ),
                      Positioned(
                        left: 22,
                        top: 110,
                        width: 318,
                        height: 545,
                        child: _InputPaper(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '店家名稱',
                                style: AppTextStyles.bodySmallBold.copyWith(
                                  color: _darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: shopNameController,
                                  maxLines: 1,
                                  style: AppTextStyles.title.copyWith(
                                    color: _darkText,
                                  ),
                                  cursorColor: _red,
                                  decoration: InputDecoration(
                                    hintText: '請勿輸入無註冊的店家名稱',
                                    hintStyle: AppTextStyles.captionSmall
                                        .copyWith(color: _hintColor),
                                    contentPadding: const EdgeInsets.only(
                                      left: 2,
                                      right: 2,
                                      bottom: 5,
                                    ),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: _lineColor,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: _lineColor,
                                        width: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '敘事語氣',
                                style: AppTextStyles.bodySmallBold.copyWith(
                                  color: _darkText,
                                ),
                              ),
                              const SizedBox(height: 5),
                              _buildToneRow(),
                              const SizedBox(height: 10),
                              Text(
                                '推廣資訊',
                                style: AppTextStyles.bodySmallBold.copyWith(
                                  color: _darkText,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                width: double.infinity,
                                height: 94,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: _lineColor,
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: promotionController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: AppTextStyles.bodySmallMedium.copyWith(
                                    color: _darkText,
                                  ),
                                  cursorColor: _red,
                                  decoration: InputDecoration(
                                    hintText: '請輸入店家優惠、特色、活動資訊',
                                    hintStyle: AppTextStyles.captionSmall
                                        .copyWith(color: _hintColor),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    '上傳',
                                    style: AppTextStyles.bodySmallBold.copyWith(
                                      color: _darkText,
                                    ),
                                  ),
                                  const Spacer(),
                                  _UploadButton(onTap: uploadFile),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _UploadArea(
                                files: uploadedFiles,
                                onRemove: removeFile,
                              ),
                              const SizedBox(height: 15),
                              Center(
                                child: _GenerateButton(
                                  text: _mmId == null ? '生成推薦' : '重新生成',
                                  busy: _generating,
                                  onTap: generate,
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
          );
        },
      ),
    );
  }
}

class _InputPaper extends StatelessWidget {
  final Widget child;

  const _InputPaper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 14),
      decoration: BoxDecoration(
        color: _paperColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: child,
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String text;
  final String iconPath;
  const _PageTitle({required this.text, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(iconPath, width: 24, height: 24),
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

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing ? 0.95 : 1.0;

    return MouseRegion(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => pressing = true),
        onTapUp: (_) => setState(() => pressing = false),
        onTapCancel: () => setState(() => pressing = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Text(
            '<< 返回',
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
    );
  }
}

class _ToneButton extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _ToneButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ToneButton> createState() => _ToneButtonState();
}

class _ToneButtonState extends State<_ToneButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing ? 0.96 : 1.0;

    return MouseRegion(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => pressing = true),
        onTapUp: (_) => setState(() => pressing = false),
        onTapCancel: () => setState(() => pressing = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected ? _lineColor : const Color(0xFFF7F5F3),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _lineColor, width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text,
                maxLines: 1,
                style: AppTextStyles.labelWide.copyWith(
                  color: widget.selected ? _paperColor : _lineColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadArea extends StatelessWidget {
  final List<_UploadItem> files;
  final Function(int) onRemove;
  const _UploadArea({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _uploadBorder),
      ),
      child: files.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: _uploadBorder,
                  size: 29,
                ),
                const SizedBox(height: 4),
                Text(
                  '尚未選擇素材',
                  style: AppTextStyles.label.copyWith(color: _uploadBorder),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 5, 8, 2),
                  child: Text(
                    '已上傳 ${files.length} 個素材',
                    style: AppTextStyles.microLabel.copyWith(color: _darkText),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 5,
                      bottom: 2,
                    ),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final item = files[index];

                      return SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              color: _uploadBorder,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.microTightBold.copyWith(
                                  color: _darkText,
                                ),
                              ),
                            ),
                            if (item.path != null)
                              GestureDetector(
                                onTap: () => onRemove(index),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.close,
                                    color: _uploadBorder,
                                    size: 17,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _UploadButton extends StatefulWidget {
  final VoidCallback onTap;

  const _UploadButton({required this.onTap});

  @override
  State<_UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends State<_UploadButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing ? 0.90 : 1.0;

    return MouseRegion(
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => pressing = true),
        onTapUp: (_) => setState(() => pressing = false),
        onTapCancel: () => setState(() => pressing = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutBack,
          child: Container(
            width: 38,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _buttonBorder, width: 1.5),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: _paperColor,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatefulWidget {
  final String text;
  final bool busy;
  final VoidCallback onTap;
  const _GenerateButton({
    required this.text,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing ? 0.96 : 1.0;

    return MouseRegion(
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        onTapDown: (_) => setState(() => pressing = true),
        onTapUp: (_) => setState(() => pressing = false),
        onTapCancel: () => setState(() => pressing = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            width: 224,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _buttonBorder, width: 2),
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.2),
                radius: 1.15,
                colors: [_buttonCenter, _buttonCenter, _buttonOuter],
                stops: [0.0, 0.45, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
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
                    style: AppTextStyles.subtitle.copyWith(color: _paperColor),
                  ),
          ),
        ),
      ),
    );
  }
}
