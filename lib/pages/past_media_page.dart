import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';

import '../block/navigationbar.dart';
import 'past_page.dart';
import 'postcard_gif_dowload.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';

const Color _pageColor = AppColors.pastBackground;
const Color _videoPoster = AppColors.paper;

class PastMediaPage extends StatefulWidget {
  final String storyId;

  const PastMediaPage({super.key, required this.storyId});

  @override
  State<PastMediaPage> createState() => _PastMediaPageState();
}

class _PastMediaPageState extends State<PastMediaPage> {
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static const double designWidth = 360;
  static const double contentScale = 1;

  static const double postcardWidth = 180;
  static const double postcardHeight = 133;
  static const double postcardGap = 16;

  int currentIndex = 3;
  int? selectedPostcardIndex;
  bool showVideo = false;
  bool isLoading = true;
  String? loadError;

  List<Map<String, dynamic>> postcards = [];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: _pageColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _fetchPostcards();
  }

  Future<void> _fetchPostcards() async {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = '尚未登入，無法取得明信片資料';
      });

      return;
    }

    if (_apiBaseUrl.isEmpty) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = '尚未設定 API_BASE_URL';
      });

      return;
    }

    try {
      final Uri url = Uri.parse(
        '$_apiBaseUrl/api/PostcardCatalog/by-story/'
        '${Uri.encodeComponent(widget.storyId)}',
      );

      final http.Response response = await http.get(
        url,
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('API 回傳格式錯誤');
      }

      if (decoded['isSuccess'] != true) {
        throw Exception(decoded['message']?.toString() ?? '明信片資料取得失敗');
      }

      final dynamic result = decoded['Result'];

      if (result is! List) {
        throw Exception('API Result 不是陣列');
      }

      final List<Map<String, dynamic>> loadedPostcards = result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['IsActive'] != false)
          .toList();

      loadedPostcards.sort((a, b) {
        final int sortA = int.tryParse(a['SortOrder']?.toString() ?? '') ?? 0;

        final int sortB = int.tryParse(b['SortOrder']?.toString() ?? '') ?? 0;

        return sortA.compareTo(sortB);
      });

      if (!mounted) return;

      setState(() {
        postcards = loadedPostcards;
        isLoading = false;
        loadError = null;
      });
    } catch (e) {
      debugPrint('取得明信片目錄失敗：$e');

      if (!mounted) return;

      setState(() {
        postcards = [];
        isLoading = false;
        loadError = '明信片資料取得失敗';
      });
    }
  }

  String _imageUrl(String? imagePath) {
    final String path = imagePath?.trim() ?? '';

    if (path.isEmpty) {
      return '';
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (path.startsWith('/')) {
      return '$_apiBaseUrl$path';
    }

    return '$_apiBaseUrl/$path';
  }

  Future<void> _downloadPostcard(Map<String, dynamic> postcard) async {
    final String imageUrl = _imageUrl(postcard['ImageUrl']?.toString());
    final int index = postcards.indexOf(postcard);
    final bool isSpecial = _isNightPostcard(postcard, index);

    try {
      if (isSpecial) {
        _showMessage('正在製作動畫明信片...');
        final String? error = await PostcardGifDownload.downloadPostcard(
          imageUrl: imageUrl,
          isSpecial: true,
        );

        if (!mounted) return;

        if (error != null) {
          _showMessage(error);
          return;
        }

        _showMessage('動畫明信片已成功儲存到相簿');
        return;
      }

      final http.Response response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final Uint8List bytes = response.bodyBytes;

      if (bytes.isEmpty) {
        throw Exception('圖片內容為空');
      }

      bool hasAccess = await Gal.hasAccess();

      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        _showMessage('沒有相簿權限，無法儲存圖片');
        return;
      }

      await Gal.putImageBytes(
        bytes,
        album: '回憶明信片',
        name: 'postcard_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      _showMessage('明信片已成功儲存到相簿');
    } on GalException catch (e) {
      _showMessage('儲存到相簿失敗：${e.type.message}');
    } catch (e) {
      _showMessage('圖片下載失敗：$e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void backToPast() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PastPage()),
    );
  }

  void openPostcard(int index) {
    if (index < 0 || index >= postcards.length) return;

    setState(() {
      selectedPostcardIndex = index;
    });
  }

  void closePostcard() {
    setState(() {
      selectedPostcardIndex = null;
    });
  }

  void openVideo() {
    setState(() {
      showVideo = true;
    });
  }

  void closeVideo() {
    setState(() {
      showVideo = false;
    });
  }

  bool _isNightPostcard(Map<String, dynamic> postcard, int index) {
    //暫時測試第一張特效
    if (index == 0) {
      return true;
    }
    final dynamic isNight = postcard['IsNightEditionDefault'];

    if (isNight == true) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: screenSize.height * 0.01,
                    bottom: 190,
                  ),
                  child: Transform.scale(
                    scale: contentScale,
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: designWidth,
                        height: 700,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Positioned.fill(
                              child: ColoredBox(color: _pageColor),
                            ),

                            Positioned(
                              left: 22,
                              top: 49,
                              child: _BackButton(onTap: backToPast),
                            ),

                            Positioned(
                              left: 25,
                              top: 88,
                              right: 25,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _OutlinedTitle(text: '回憶vlog'),
                                  const Spacer(),

                                  _ActionIcon(
                                    icon: Icons.download_rounded,
                                    onTap: () {},
                                  ),

                                  const SizedBox(width: 12),

                                  _ActionIcon(
                                    icon: Icons.share_rounded,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),

                            Positioned(
                              left: 15,
                              right: 15,
                              top: 140,
                              height: 350,
                              child: _VideoSection(onTap: openVideo),
                            ),

                            Positioned(
                              left: 25,
                              top: 500,
                              child: _OutlinedTitle(text: '明信片集結'),
                            ),

                            Positioned(
                              left: 0,
                              right: 0,
                              top: 535,
                              height: 163,
                              child: _buildPostcardArea(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (selectedPostcardIndex != null &&
              selectedPostcardIndex! >= 0 &&
              selectedPostcardIndex! < postcards.length)
            Positioned.fill(
              child: _PostcardOverlay(
                imageUrl: _imageUrl(
                  postcards[selectedPostcardIndex!]['ImageUrl']?.toString(),
                ),
                postcardName:
                    postcards[selectedPostcardIndex!]['PostcardName']
                        ?.toString() ??
                    '',
                summary:
                    postcards[selectedPostcardIndex!]['Summary']?.toString() ??
                    '',
                isSpecial: _isNightPostcard(
                  postcards[selectedPostcardIndex!],
                  selectedPostcardIndex!,
                ),
                onClose: closePostcard,
                onDownload: () {
                  _downloadPostcard(postcards[selectedPostcardIndex!]);
                },
              ),
            ),

          if (showVideo)
            Positioned.fill(child: _VideoOverlay(onClose: closeVideo)),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  Widget _buildPostcardArea() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.secondaryRed,
        ),
      );
    }

    if (loadError != null) {
      return Center(
        child: Text(
          loadError!,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    if (postcards.isEmpty) {
      return Center(
        child: Text(
          '目前沒有明信片資料',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    return _PostcardCarousel(
      postcards: postcards,
      imageUrlBuilder: _imageUrl,
      isNightBuilder: _isNightPostcard,
      onPostcardTap: openPostcard,
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
    final double scale = pressing ? 0.95 : 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => pressing = true);
      },
      onTapUp: (_) {
        setState(() => pressing = false);
      },
      onTapCancel: () {
        setState(() => pressing = false);
      },
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Text(
          '<< 返回',
          style: AppTextStyles.button.copyWith(color: const Color(0xFFE8DCC6)),
        ),
      ),
    );
  }
}

class _OutlinedTitle extends StatelessWidget {
  final String text;

  const _OutlinedTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final TextStyle outlineStyle = AppTextStyles.heading
        .copyWith(color: Colors.white)
        .copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.black,
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(text, style: outlineStyle),
        Text(text, style: AppTextStyles.heading.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.onTap});

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => pressing = true);
      },
      onTapUp: (_) {
        setState(() => pressing = false);
      },
      onTapCancel: () {
        setState(() => pressing = false);
      },
      child: AnimatedScale(
        scale: pressing ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.2,
            ),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 17),
        ),
      ),
    );
  }
}

class _VideoSection extends StatelessWidget {
  final VoidCallback onTap;

  const _VideoSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 240,
          height: 426.67,
          decoration: BoxDecoration(
            color: _videoPoster,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.white, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _VideoOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const _VideoOverlay({required this.onClose});

  @override
  State<_VideoOverlay> createState() => _VideoOverlayState();
}

class _VideoOverlayState extends State<_VideoOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.82)),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final double value = Curves.easeOutBack.transform(
                      controller.value,
                    );

                    return Transform.scale(
                      scale: value,
                      child: GestureDetector(
                        onTap: () {},
                        child: const _VideoPlayerCard(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            right: 18,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerCard extends StatelessWidget {
  const _VideoPlayerCard();

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    final double width = math.min(screenSize.width * 0.92, 520.0);

    final double height = math.min(screenSize.height * 0.82, width * 16 / 9);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _videoPoster,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xAA000000), blurRadius: 30, spreadRadius: 5),
        ],
      ),
    );
  }
}

class _PostcardCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> postcards;
  final String Function(String?) imageUrlBuilder;
  final bool Function(Map<String, dynamic>, int) isNightBuilder;
  final ValueChanged<int> onPostcardTap;

  const _PostcardCarousel({
    required this.postcards,
    required this.imageUrlBuilder,
    required this.isNightBuilder,
    required this.onPostcardTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FlutterCarousel(
        options: FlutterCarouselOptions(
          height: 163,
          viewportFraction: 0.55,
          initialPage: postcards.length > 1 ? 1 : 0,
          enableInfiniteScroll: postcards.length > 1,
          autoPlay: false,
          enlargeCenterPage: false,
          showIndicator: false,
          pageSnapping: true,
          scrollDirection: Axis.horizontal,
        ),
        items: List.generate(postcards.length, (index) {
          final Map<String, dynamic> postcard = postcards[index];

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _PastMediaPageState.postcardGap / 2,
              ),
              child: _PostcardCard(
                imageUrl: imageUrlBuilder(postcard['ImageUrl']?.toString()),
                postcardName: postcard['PostcardName']?.toString() ?? '',
                summary: postcard['Summary']?.toString() ?? '',
                isSpecial: isNightBuilder(postcard, index),
                onTap: () => onPostcardTap(index),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PostcardCard extends StatefulWidget {
  final String imageUrl;
  final String postcardName;
  final String summary;
  final bool isSpecial;
  final VoidCallback onTap;

  const _PostcardCard({
    required this.imageUrl,
    required this.postcardName,
    required this.summary,
    required this.isSpecial,
    required this.onTap,
  });

  @override
  State<_PostcardCard> createState() => _PostcardCardState();
}

class _PostcardCardState extends State<_PostcardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  bool pressing = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.isSpecial) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() => pressing = true);
      },
      onTapUp: (_) {
        setState(() => pressing = false);
      },
      onTapCancel: () {
        setState(() => pressing = false);
      },
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return _PostcardVisual(
              imageUrl: widget.imageUrl,
              postcardName: widget.postcardName,
              isSpecial: widget.isSpecial,
              progress: controller.value,
            );
          },
        ),
      ),
    );
  }
}

class _PostcardVisual extends StatelessWidget {
  final String imageUrl;
  final String postcardName;
  final bool isSpecial;
  final double progress;

  const _PostcardVisual({
    required this.imageUrl,
    required this.postcardName,
    required this.isSpecial,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _PastMediaPageState.postcardWidth,
      height: _PastMediaPageState.postcardHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: isSpecial
                ? Color.lerp(
                    const Color(0x44000000),
                    const Color(0xFF7568FF),
                    progress,
                  )!
                : const Color(0x44000000),
            blurRadius: isSpecial ? 14 : 6,
            spreadRadius: isSpecial ? 1 : 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.paper,
                    alignment: Alignment.center,
                    child: Text(
                      '圖片載入失敗',
                      style: AppTextStyles.microLabel.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.paper,
                alignment: Alignment.center,
                child: Text(
                  '尚無圖片',
                  style: AppTextStyles.microLabel.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

            if (isSpecial)
              CustomPaint(painter: _NightCardPainter(progress: progress)),
          ],
        ),
      ),
    );
  }
}

class _StarData {
  final double x;
  final double y;
  final double radius;
  final double phase;

  const _StarData(this.x, this.y, this.radius, this.phase);
}

class _NightCardPainter extends CustomPainter {
  final double progress;

  const _NightCardPainter({required this.progress});

  // 少量星塵
  static const List<_StarData> stars = [
    _StarData(0.12, 0.20, 0.8, 0.00),
    _StarData(0.30, 0.38, 0.6, 0.24),
    _StarData(0.76, 0.18, 0.9, 0.46),
    _StarData(0.88, 0.48, 0.6, 0.68),
    _StarData(0.20, 0.78, 0.7, 0.35),
    _StarData(0.78, 0.80, 0.9, 0.58),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 很淡的夜間色調
    final Paint tint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x222B2470),
          Color(0x08101845),
          Color(0x302E267A),
          Color(0x08101845),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, tint);

    // 少量漂浮星塵
    final Paint starPaint = Paint();

    for (final star in stars) {
      final double wave = (progress + star.phase) % 1.0;

      // 緩慢漂浮
      final double floatY =
          math.sin((progress * math.pi * 2) + star.phase * math.pi * 2) * 1.2;

      final Offset center = Offset(
        size.width * star.x,
        size.height * star.y + floatY,
      );

      // 微微閃爍
      final double glow =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(wave * math.pi * 2));

      final double opacity = (0.18 + glow * 0.38).clamp(0.12, 0.55);

      starPaint.color = Colors.white.withValues(alpha: opacity);

      canvas.drawCircle(center, star.radius, starPaint);
    }

    // 月光掃過
    final double sweep = progress;

    final double moonX = -size.width * 0.35 + sweep * size.width * 1.7;

    final Rect moonRect = Rect.fromCenter(
      center: Offset(moonX, size.height * 0.42),
      width: size.width * 0.42,
      height: size.height * 1.5,
    );

    final Paint moonLight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0x127D6CFF),
          const Color(0x35FFFFFF),
          const Color(0x127D6CFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
      ).createShader(moonRect);

    canvas.save();
    canvas.rotate(-0.18);
    canvas.drawRect(moonRect, moonLight);
    canvas.restore();

    // SSR 流光邊框
    final Paint borderGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x337D6CFF);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(3)),
      borderGlow,
    );

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0x227D6CFF),
          Color(0x66FFFFFF),
          Color(0xFFFFFFFF),
          Color(0x667D6CFF),
          Color(0x227D6CFF),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(3)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _NightCardPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PostcardOverlay extends StatefulWidget {
  final String imageUrl;
  final String postcardName;
  final String summary;
  final bool isSpecial;
  final VoidCallback onClose;
  final VoidCallback onDownload;

  const _PostcardOverlay({
    required this.imageUrl,
    required this.postcardName,
    required this.summary,
    required this.isSpecial,
    required this.onClose,
    required this.onDownload,
  });

  @override
  State<_PostcardOverlay> createState() => _PostcardOverlayState();
}

class _PostcardOverlayState extends State<_PostcardOverlay>
    with TickerProviderStateMixin {
  late final AnimationController openController;
  late final AnimationController effectController;

  @override
  void initState() {
    super.initState();

    openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (widget.isSpecial) {
      effectController.repeat();
    }
  }

  @override
  void dispose() {
    openController.dispose();
    effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return GestureDetector(
                  onTap: widget.onClose,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: 9 * value,
                      sigmaY: 9 * value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.74 * value),
                    ),
                  ),
                );
              },
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              child: AnimatedBuilder(
                animation: openController,
                builder: (context, child) {
                  final double scale = Curves.easeOutBack.transform(
                    openController.value,
                  );

                  return Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: effectController,
                            builder: (context, child) {
                              return _ZoomablePostcard(
                                imageUrl: widget.imageUrl,
                                postcardName: widget.postcardName,
                                summary: widget.summary,
                                isSpecial: widget.isSpecial,
                                progress: effectController.value,
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ActionIcon(
                                icon: Icons.download_rounded,
                                onTap: widget.onDownload,
                              ),

                              const SizedBox(width: 14),

                              _ActionIcon(
                                icon: Icons.print_rounded,
                                onTap: () {},
                              ),

                              const SizedBox(width: 14),

                              _ActionIcon(
                                icon: Icons.share_rounded,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 14,
            right: 18,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePostcard extends StatefulWidget {
  final String imageUrl;
  final String postcardName;
  final String summary;
  final bool isSpecial;
  final double progress;

  const _ZoomablePostcard({
    required this.imageUrl,
    required this.postcardName,
    required this.summary,
    required this.isSpecial,
    required this.progress,
  });

  @override
  State<_ZoomablePostcard> createState() => _ZoomablePostcardState();
}

class _ZoomablePostcardState extends State<_ZoomablePostcard> {
  double scale = 1.0;
  Offset offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          scale = details.scale.clamp(1.0, 4.0);
          offset += details.focalPointDelta;
        });
      },
      onScaleEnd: (_) {
        setState(() {
          scale = 1.0;
          offset = Offset.zero;
        });
      },
      child: Transform.translate(
        offset: offset,
        child: Transform.scale(
          scale: scale,
          child: _ExpandedPostcard(
            imageUrl: widget.imageUrl,
            postcardName: widget.postcardName,
            summary: widget.summary,
            isSpecial: widget.isSpecial,
            progress: widget.progress,
          ),
        ),
      ),
    );
  }
}

class _ExpandedPostcard extends StatelessWidget {
  final String imageUrl;
  final String postcardName;
  final String summary;
  final bool isSpecial;
  final double progress;

  const _ExpandedPostcard({
    required this.imageUrl,
    required this.postcardName,
    required this.summary,
    required this.isSpecial,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    final double maxWidth = screenSize.width < 520
        ? screenSize.width * 0.88
        : 520;

    final double cardHeight =
        maxWidth *
        _PastMediaPageState.postcardHeight /
        _PastMediaPageState.postcardWidth;

    return Container(
      width: maxWidth,
      height: cardHeight,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: isSpecial
                ? const Color(0xAA7568FF)
                : const Color(0xAA000000),
            blurRadius: isSpecial ? 38 : 25,
            spreadRadius: isSpecial ? 3 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.paper,
                    alignment: Alignment.center,
                    child: Text(
                      '圖片載入失敗',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.paper,
                alignment: Alignment.center,
                child: Text(
                  '尚無圖片',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

            if (isSpecial)
              CustomPaint(painter: _ExpandedNightPainter(progress: progress)),

            if (postcardName.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    postcardName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedNightPainter extends CustomPainter {
  final double progress;

  const _ExpandedNightPainter({required this.progress});

  // 少量星塵，避免放大後畫面太滿
  static const List<_StarData> stars = [
    _StarData(0.12, 0.20, 1.5, 0.00),
    _StarData(0.30, 0.38, 1.1, 0.24),
    _StarData(0.76, 0.18, 1.7, 0.46),
    _StarData(0.88, 0.48, 1.1, 0.68),
    _StarData(0.20, 0.78, 1.3, 0.35),
    _StarData(0.78, 0.80, 1.6, 0.58),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 夜間 SSR 淡淡的紫藍色氛圍
    final Paint tint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x30342B91),
          Color(0x08101845),
          Color(0x3A3C247D),
          Color(0x08101845),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, tint);

    // 少量漂浮星塵
    for (final star in stars) {
      final double wave = (progress + star.phase) % 1.0;

      final double floatX =
          math.sin(progress * math.pi * 2 + star.phase * math.pi * 2) * 1.8;

      final double floatY =
          math.cos(progress * math.pi * 2 + star.phase * math.pi * 2) * 1.5;

      final Offset center = Offset(
        size.width * star.x + floatX,
        size.height * star.y + floatY,
      );

      // 微微閃爍
      final double glow = 0.5 + 0.5 * math.sin(wave * math.pi * 2);

      final double opacity = (0.18 + glow * 0.42).clamp(0.12, 0.6);

      canvas.drawCircle(
        center,
        star.radius,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // 月光掃過
    final double sweep = progress;

    final double moonX = -size.width * 0.35 + sweep * size.width * 1.7;

    final Rect moonRect = Rect.fromCenter(
      center: Offset(moonX, size.height * 0.42),
      width: size.width * 0.36,
      height: size.height * 1.5,
    );

    final Paint moonLight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0x107D6CFF),
          const Color(0x35FFFFFF),
          const Color(0x107D6CFF),
          Colors.transparent,
        ],
        stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
      ).createShader(moonRect);

    canvas.save();
    canvas.rotate(-0.18);
    canvas.drawRect(moonRect, moonLight);
    canvas.restore();

    // SSR 流光外框：淡淡的紫藍光暈
    final Paint borderGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x287D6CFF);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(5)),
      borderGlow,
    );

    // SSR 流光主邊框
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Color(0x227D6CFF),
          Color(0x88FFFFFF),
          Color(0xFFFFFFFF),
          Color(0x88756BFF),
          Color(0x227D6CFF),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(5)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _ExpandedNightPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
