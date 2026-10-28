import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/story_api.dart';
import '../api/vlog_watcher.dart';
import '../core/app_colors.dart';
import '../core/app_notice.dart';
import '../core/app_text_styles.dart';

const Color _backgroundColor = AppColors.storyBackground;
const Color _lightText = AppColors.paper;
const Color _cardColor = Color(0xFFF4EBD8);
const Color _cardBorder = Color(0xFFDEB019);
const Color _darkText = AppColors.textPrimary;

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

enum _Stage { loading, preview, creating, failed }

class VlogCheckPage extends StatefulWidget {
  final String storyId;

  const VlogCheckPage({super.key, required this.storyId});

  @override
  State<VlogCheckPage> createState() => _VlogCheckPageState();
}

class _VlogCheckPageState extends State<VlogCheckPage> {
  final TextEditingController _scriptController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();
  final TextEditingController _memoryController = TextEditingController();
  List<Map<String, dynamic>> _moods = [];
  String _mood = 'auto';
  int _memoryMax = 3000;

  _Stage _stage = _Stage.loading;
  String _error = '';
  Map<String, dynamic> _data = {};

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

    _loadPreview();
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _promoController.dispose();
    _memoryController.dispose();
    super.dispose();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

  List<Map<String, dynamic>> get _spots {
    final dynamic raw = _data['spots'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<String> get _keywords {
    final dynamic raw = _data['seo_keywords'];

    if (raw is! List) return [];

    return raw.map((e) => e.toString()).toList();
  }

  String _description(Map<String, dynamic> spot) {
    final dynamic raw = _data['itinerary'];

    if (raw is! List) return '';

    for (final dynamic item in raw) {
      if (item is Map && _text(item['spot_name']) == _text(spot['spot_name'])) {
        return _text(item['db_description']);
      }
    }

    return '';
  }

  String _spotImage(Map<String, dynamic> spot) {
    final dynamic images = spot['images'];

    if (images is List) {
      for (final dynamic item in images) {
        final String url = _text(
          item is Map ? (item['url'] ?? item['image_url']) : item,
        );

        if (url.startsWith('http')) return url;
      }
    }

    return '';
  }

  Future<void> _loadPreview() async {
    setState(() {
      _stage = _Stage.loading;
      _error = '';
    });

    try {
      final Map<String, dynamic> data = await StoryApi.previewVisitorVlog(
        storyId: widget.storyId,
      );

      try {
        final Map<String, dynamic> options = await StoryApi.getVlogOptions();
        final dynamic raw = options['bgm_moods'];

        if (raw is List) {
          _moods = raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          for (final Map<String, dynamic> mood in _moods) {
            if (mood['is_default'] == true) _mood = _text(mood['value']);
          }
        }

        _memoryMax =
            int.tryParse(_text(options['user_memory_text_max_length'])) ?? 3000;
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _data = data;
        _scriptController.text = _text(data['script']);
        _promoController.text = _text(data['promo_copy']);
        _stage = _Stage.preview;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _message(e);
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _confirm() async {
    final String script = _scriptController.text.trim();

    if (script.isEmpty) {
      _snack('旁白不能是空的');
      return;
    }

    setState(() {
      _stage = _Stage.creating;
    });

    try {
      final Map<String, dynamic> result = await StoryApi.createFinalVisitorVlog(
        storyId: widget.storyId,
        finalScript: script,
        promoCopy: _promoController.text.trim(),
        seoKeywords: _keywords,
        bgmMood: _mood,
        userMemoryText: _memoryController.text,
      );

      final String taskId = _text(result['task_id']);
      if (taskId.isEmpty) {
        throw Exception('後端沒有回傳 Vlog 任務編號');
      }
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);

      VlogWatcher.start(storyId: widget.storyId, taskId: taskId);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _message(e);
        _stage = _Stage.failed;
      });
    }
  }

  void _snack(String message) {
    AppNotice.show(message);
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.loading:
        return const _FilmStatus(title: '旁白撰寫中', subtitle: '正在把你的旅程寫成腳本……');
      case _Stage.creating:
        return const _FilmStatus(title: '送出確認中', subtitle: '正在把旁白交給剪輯師……');
      case _Stage.failed:
        return _buildResult(
          icon: Icons.error_outline_rounded,
          title: '發生問題',
          message: _error,
          button: '返回首頁',
          onTap: _goHome,
          secondary: _data.isEmpty ? '重新嘗試' : null,
          onSecondary: _loadPreview,
        );
      case _Stage.preview:
        return _buildPreview();
    }
  }

  Widget _buildResult({
    required IconData icon,
    required String title,
    required String message,
    required String button,
    required VoidCallback onTap,
    String? secondary,
    VoidCallback? onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: _cardBorder),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(color: _lightText),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            if (secondary != null) ...[
              _VlogButton(text: secondary, onTap: onSecondary!),
              const SizedBox(height: 12),
            ],
            _VlogButton(text: button, onTap: onTap),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
      children: [
        Text(
          '旅程回憶確認',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          _text(_data['story_title']),
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(color: _lightText),
        ),
        const SizedBox(height: 18),
        for (final Map<String, dynamic> spot in _spots) _buildSpot(spot),
        const SizedBox(height: 6),
        _buildField(title: '旁白', controller: _scriptController, lines: 4),
        const SizedBox(height: 14),
        _buildField(title: '宣傳文案', controller: _promoController, lines: 3),
        const SizedBox(height: 14),
        _buildMoods(),
        const SizedBox(height: 14),
        _buildField(
          title: '旅遊感想（選填）',
          controller: _memoryController,
          lines: 3,
          maxLength: _memoryMax,
        ),
        const SizedBox(height: 24),
        _VlogButton(text: '確認並製作 Vlog', onTap: _confirm),
      ],
    );
  }

  Widget _buildSpot(Map<String, dynamic> spot) {
    final String image = _spotImage(spot);
    final String description = _description(spot);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: image.isEmpty
                ? Container(
                    color: const Color(0xFFE2D8BD),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: Color(0xFF8C8176),
                    ),
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFE2D8BD),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 36,
                        color: Color(0xFF8C8176),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${_text(spot['order'])} 站　${_text(spot['spot_name'])}',
                  style: AppTextStyles.bodyEmphasisBold.copyWith(
                    color: AppColors.primaryAccent,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: _darkText,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoods() {
    if (_moods.isEmpty) return const SizedBox.shrink();

    String description = '';

    for (final Map<String, dynamic> mood in _moods) {
      if (_text(mood['value']) == _mood) {
        description = _text(mood['description']);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '配樂風格',
            style: AppTextStyles.bodyBold.copyWith(color: _darkText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final Map<String, dynamic> mood in _moods)
                ChoiceChip(
                  label: Text(_text(mood['label'])),
                  labelStyle: TextStyle(
                    color: _mood == _text(mood['value'])
                        ? Colors.white
                        : _darkText,
                  ),
                  checkmarkColor: Colors.white,
                  selected: _mood == _text(mood['value']),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: _cardColor,
                  onSelected: (_) =>
                      setState(() => _mood = _text(mood['value'])),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTextStyles.caption.copyWith(color: _darkText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField({
    required String title,
    required TextEditingController controller,
    required int lines,
    int? maxLength,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyBold.copyWith(color: _darkText)),
          TextField(
            controller: controller,
            minLines: lines,
            maxLines: lines + 3,
            maxLength: maxLength,
            cursorColor: AppColors.primaryAccent,
            style: AppTextStyles.caption.copyWith(
              color: _darkText,
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.only(top: 6, bottom: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _VlogButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _VlogButton({required this.text, required this.onTap});

  @override
  State<_VlogButton> createState() => _VlogButtonState();
}

class _VlogButtonState extends State<_VlogButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutBack,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: _buttonBorder, width: 2),
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.2),
              radius: 1.15,
              colors: [_buttonCenter, _buttonCenter, _buttonOuter],
              stops: [0.0, 0.45, 1.0],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.text,
            style: AppTextStyles.sectionTitle.copyWith(
              color: _lightText,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilmStatus extends StatefulWidget {
  final String title;
  final String subtitle;

  const _FilmStatus({required this.title, required this.subtitle});

  @override
  State<_FilmStatus> createState() => _FilmStatusState();
}

class _FilmStatusState extends State<_FilmStatus>
    with SingleTickerProviderStateMixin {
  static const double _cell = 60;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _frame(int index) {
    return SizedBox(
      width: _cell,
      height: 64,
      child: Stack(
        children: [
          for (final double x in [8, 40])
            for (final double y in [4, 54])
              Positioned(
                left: x,
                top: y,
                child: Container(
                  width: 10,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D5B48),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
          Positioned(
            left: 6,
            top: 13,
            width: 48,
            height: 38,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x33F4EBD8),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0x66DEB019)),
              ),
              child: Icon(
                index.isEven
                    ? Icons.movie_creation_outlined
                    : Icons.photo_camera_outlined,
                size: 20,
                color: const Color(0xFFDEB019),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double t = _controller.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: t * math.pi * 2,
                    child: const SizedBox(
                      width: 96,
                      height: 96,
                      child: CustomPaint(painter: _ReelPainter()),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 240,
                      height: 64,
                      color: const Color(0xFF241710),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (int i = -1; i < 5; i++)
                            Positioned(
                              left: i * _cell - t * _cell,
                              top: 0,
                              child: _frame(i + 1),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Text(
            widget.title,
            style: AppTextStyles.title.copyWith(color: _lightText),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ReelPainter extends CustomPainter {
  const _ReelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 2;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2B211B));

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFDEB019),
    );

    final Paint hole = Paint()..color = _backgroundColor;

    for (int i = 0; i < 6; i++) {
      final double a = i * math.pi / 3;

      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * (r * 0.58),
        r * 0.18,
        hole,
      );
    }

    canvas.drawCircle(c, r * 0.16, Paint()..color = const Color(0xFFDEB019));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
