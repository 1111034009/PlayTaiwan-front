import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'merchant_loading_page.dart';

const Color _pageColor = Color(0xFFB9ACA2);
const Color _paperColor = Color(0xFFEBE1C7);
const Color _darkText = Color(0xFF301717);
const Color _lineColor = Color(0xFF473737);
const Color _hintColor = Color(0xFF7F756D);
const Color _red = Color(0xFF7F1A08);
const Color _buttonBorder = Color(0xFF4A1106);
const Color _buttonCenter = Color(0xFF9B2A15);
const Color _buttonOuter = Color(0xFF7D1907);
const Color _uploadBorder = Color(0xFF6D625B);

class MerchantInputPage extends StatefulWidget {
  const MerchantInputPage({super.key});

  @override
  State<MerchantInputPage> createState() => _MerchantInputPageState();
}

class _MerchantInputPageState extends State<MerchantInputPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;
  static const int maxUploadFiles = 6;

  final TextEditingController shopNameController = TextEditingController(
    text: '日式復古串燒居酒屋',
  );
  final TextEditingController promotionController = TextEditingController();

  int selectedTone = 0;
  final List<String> uploadedFiles = [];

  @override
  void initState() {
    super.initState();

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
    shopNameController.dispose();
    promotionController.dispose();
    super.dispose();
  }

  TextStyle kaisei({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = _darkText,
  }) {
    return GoogleFonts.kaiseiHarunoUmi(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: kaisei(
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void uploadFile() {
    if (uploadedFiles.length >= maxUploadFiles) {
      showMessage('最多可以上傳 6 個素材');
      return;
    }

    setState(() {
      uploadedFiles.add('promotion_image_${uploadedFiles.length + 1}.jpg');
    });

    showMessage('已加入素材：${uploadedFiles.last}');
  }

  void removeFile(int index) {
    final fileName = uploadedFiles[index];

    setState(() {
      uploadedFiles.removeAt(index);
    });

    showMessage('已移除：$fileName');
  }

  void generate() {
    if (shopNameController.text.trim().isEmpty) {
      showMessage('請輸入店家名稱');
      return;
    }

    if (uploadedFiles.isEmpty) {
      showMessage('請至少上傳一個素材');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VideoLoadingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = [
            constraints.maxWidth / designWidth,
            constraints.maxHeight / designHeight,
          ].reduce((a, b) => a < b ? a : b);

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
                        top: 20,
                        child: _BackButton(
                          onTap: () => Navigator.pop(context),
                          kaisei: kaisei,
                        ),
                      ),
                      Positioned(
                        top: 48,
                        left: 0,
                        width: designWidth,
                        child: Center(
                          child: _PageTitle(
                            text: '輸入資訊',
                            iconPath: 'img/user_icon_line.png',
                            kaisei: kaisei,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 82,
                        child: Center(
                          child: Text(
                            '輸入資訊，生成專屬推廣短影音',
                            textAlign: TextAlign.center,
                            style:
                                kaisei(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ).copyWith(
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
                        top: 108,
                        width: 318,
                        height: 507,
                        child: _InputPaper(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '店家名稱',
                                style: kaisei(
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: shopNameController,
                                  maxLines: 1,
                                  style: kaisei(
                                    size: 21,
                                    weight: FontWeight.w700,
                                  ),
                                  cursorColor: _red,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.only(
                                      left: 2,
                                      right: 2,
                                      bottom: 5,
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: _lineColor,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: _lineColor,
                                        width: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                '敘事語氣',
                                style: kaisei(
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ToneButton(
                                      text: '幽默歡謔',
                                      selected: selectedTone == 0,
                                      onTap: () =>
                                          setState(() => selectedTone = 0),
                                      kaisei: kaisei,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: _ToneButton(
                                      text: '質感專業',
                                      selected: selectedTone == 1,
                                      onTap: () =>
                                          setState(() => selectedTone = 1),
                                      kaisei: kaisei,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: _ToneButton(
                                      text: '溫情走心',
                                      selected: selectedTone == 2,
                                      onTap: () =>
                                          setState(() => selectedTone = 2),
                                      kaisei: kaisei,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              Text(
                                '推廣資訊',
                                style: kaisei(
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                                  style: kaisei(
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                  cursorColor: _red,
                                  decoration: InputDecoration(
                                    hintText: '請輸入店家優惠、特色、活動資訊',
                                    hintStyle: kaisei(
                                      size: 13,
                                      color: _hintColor,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '上傳',
                                    style: kaisei(
                                      size: 14,
                                      weight: FontWeight.w700,
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
                                kaisei: kaisei,
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: _GenerateButton(
                                  text: '生成推薦',
                                  onTap: generate,
                                  kaisei: kaisei,
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
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _PageTitle({
    required this.text,
    required this.iconPath,
    required this.kaisei,
  });

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
              style:
                  kaisei(
                    size: 23,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ).copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 2.6
                      ..color = _darkText,
                  ),
            ),
            Text(
              text,
              style: kaisei(
                size: 23,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _BackButton({required this.onTap, required this.kaisei});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing
        ? 0.95
        : hovering
        ? 1.06
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
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
            style: widget
                .kaisei(
                  size: 14,
                  weight: FontWeight.w700,
                  color: const Color(0xFFFAF7F1),
                )
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
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _ToneButton({
    required this.text,
    required this.selected,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_ToneButton> createState() => _ToneButtonState();
}

class _ToneButtonState extends State<_ToneButton> {
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing
        ? 0.96
        : hovering
        ? 1.04
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
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
            child: Text(
              widget.text,
              style: widget.kaisei(
                size: 12.5,
                weight: FontWeight.w700,
                color: widget.selected ? _paperColor : _lineColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadArea extends StatefulWidget {
  final List<String> files;
  final Function(int) onRemove;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _UploadArea({
    required this.files,
    required this.onRemove,
    required this.kaisei,
  });

  @override
  State<_UploadArea> createState() => _UploadAreaState();
}

class _UploadAreaState extends State<_UploadArea> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedScale(
        scale: hovering ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _uploadBorder),
          ),
          child: widget.files.isEmpty
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
                      style: widget.kaisei(
                        size: 12,
                        weight: FontWeight.w700,
                        color: _uploadBorder,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 8, 2),
                      child: Text(
                        '已上傳 ${widget.files.length} 個素材',
                        style: widget.kaisei(
                          size: 11,
                          weight: FontWeight.w700,
                          color: _darkText,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 5,
                          bottom: 2,
                        ),
                        itemCount: widget.files.length,
                        itemBuilder: (context, index) {
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
                                    widget.files[index],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: widget.kaisei(
                                      size: 10.5,
                                      weight: FontWeight.w700,
                                      color: _darkText,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => widget.onRemove(index),
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
        ),
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
  bool hovering = false;
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final scale = pressing
        ? 0.90
        : hovering
        ? 1.08
        : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
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
  final VoidCallback onTap;
  final TextStyle Function({double size, FontWeight weight, Color color})
  kaisei;

  const _GenerateButton({
    required this.text,
    required this.onTap,
    required this.kaisei,
  });

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
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
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
            child: Text(
              widget.text,
              style: widget.kaisei(
                size: 17,
                weight: FontWeight.w700,
                color: _paperColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
