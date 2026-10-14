import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:http/http.dart' as http;
import '../block/navigationbar.dart';
import 'past_page.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';
import 'past_media_page.dart';

const Color _pageColor = AppColors.pastBackground;

const Color _darkBrown = AppColors.darkBrown;
const Color _darkText = AppColors.textPrimary;
const Color _sectionRed = AppColors.primaryAccent;

const Color _photoColor = AppColors.postcard;
const Color _photoBorder = AppColors.postcardLine;

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

class PastDetailPage extends StatefulWidget {
  final String storyId;
  final String title;
  final String completedDate;

  const PastDetailPage({
    super.key,
    required this.storyId,
    this.title = '府城儒生失落卷',
    this.completedDate = '2026.08.09',
  });

  @override
  State<PastDetailPage> createState() => _PastDetailPageState();
}

class _PastDetailPageState extends State<PastDetailPage> {
  static const double designWidth = 360;
  static const double contentScale = 1.06;
  static const double paperMinHeight = 500;

  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  int currentIndex = 3;

  String title = '';
  String completedDate = '';
  String synopsis = '';
  String region = '';
  List<String> routeSummary = [];

  bool isLoading = true;

  static const List<String> photoAssets = [
    'img/home_trip.png',
    'img/home_gogo.png',
    'img/home_trip.png',
  ];

  List<Map<String, String>> photos = [];

  String _imageUrl(String? path) {
    final String value = path?.trim() ?? '';

    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    return '$_apiBaseUrl/${value.replaceFirst(RegExp(r'^/'), '')}';
  }

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
    title = widget.title;
    completedDate = widget.completedDate;
    _fetchHistoryDetail();
  }

  Future<void> _fetchHistoryDetail() async {
    final token = AppSession.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse(
          '$_apiBaseUrl/api/History/${Uri.encodeComponent(widget.storyId)}',
        ),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (data['isSuccess'] == true) {
          final dynamic result = data['Result'];
          if (result is Map<String, dynamic>) {
            final dynamic apiTitle = result['title'];
            final dynamic apiCompletedDate = result['completed_date'];
            final dynamic apiSynopsis = result['synopsis'];
            final dynamic apiRegion = result['region'];
            final dynamic apiSpots = result['spots'];

            DateTime? parsedDate;
            if (apiCompletedDate is String && apiCompletedDate.isNotEmpty) {
              parsedDate = DateTime.tryParse(apiCompletedDate);
            }

            final List<String> routes = apiSpots is List
                ? apiSpots
                      .whereType<String>()
                      .where((item) => item.trim().isNotEmpty)
                      .toList()
                : [];

            final dynamic apiPhotos = result['photos'];

            final List<Map<String, String>> loadedPhotos = apiPhotos is List
                ? apiPhotos
                      .whereType<Map>()
                      .map(
                        (item) => {
                          'url': _imageUrl(item['image_url']?.toString()),
                          'name': item['place_name']?.toString() ?? '',
                        },
                      )
                      .where((item) => item['url']!.isNotEmpty)
                      .toList()
                : [];

            final String cover = _imageUrl(
              result['cover_image_url']?.toString(),
            );

            if (loadedPhotos.isEmpty && cover.isNotEmpty) {
              loadedPhotos.add({'url': cover, 'name': ''});
            }

            if (!mounted) return;

            setState(() {
              title = apiTitle is String && apiTitle.isNotEmpty
                  ? apiTitle
                  : widget.title;

              completedDate = parsedDate != null
                  ? _formatCompletedDate(parsedDate)
                  : widget.completedDate;

              synopsis = apiSynopsis is String ? apiSynopsis : '';

              region = apiRegion is String ? apiRegion : '';

              routeSummary = routes;

              photos = loadedPhotos;

              isLoading = false;
            });

            return;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatCompletedDate(DateTime date) {
    return '${date.year}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void backToPast() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PastPage()),
    );
  }

  Widget _buildPaperContent() {
    if (isLoading) {
      return const SizedBox(
        height: paperMinHeight - 70,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.secondaryRed,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.heading.copyWith(color: _darkText),
        ),
        Text(
          '完成日期：$completedDate',
          style: AppTextStyles.label.copyWith(color: _sectionRed),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 128,
          child: FlutterCarousel(
            options: FlutterCarouselOptions(
              height: 128,
              viewportFraction: 0.68,
              initialPage: 0,
              enableInfiniteScroll: photos.length > 1,
              autoPlay: false,
              enlargeCenterPage: true,
              showIndicator: false,
              pageSnapping: true,
              scrollDirection: Axis.horizontal,
              enlargeStrategy: CenterPageEnlargeStrategy.scale,
            ),
            items: photos.isEmpty
                ? photoAssets
                      .map((asset) => _PastPhoto(assetPath: asset, label: ''))
                      .toList()
                : photos
                      .map(
                        (photo) => _PastPhoto(
                          imageUrl: photo['url'],
                          label: photo['name'] ?? '',
                        ),
                      )
                      .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '←  左右滑動探索  →',
            textAlign: TextAlign.center,
            style: AppTextStyles.microLabel.copyWith(color: _darkBrown),
          ),
        ),
        const SizedBox(height: 8),
        Text('探索總覽', style: AppTextStyles.button.copyWith(color: _sectionRed)),
        const SizedBox(height: 6),
        if (routeSummary.isNotEmpty)
          ...routeSummary.asMap().entries.map((entry) {
            final int stationNumber = entry.key + 1;

            return _ChapterItem(
              number: '第${_toChineseNumber(stationNumber)}站',
              title: entry.value,
            );
          })
        else
          const _ChapterItem(number: '第一站', title: '暫無路線資料'),
        const SizedBox(height: 5),
        Center(
          child: _PrimaryButton(
            text: '查看明信片與專屬紀錄片',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PastMediaPage(storyId: widget.storyId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(top: topInset),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: designWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 55),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              constraints: const BoxConstraints(
                                minHeight: paperMinHeight,
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                19,
                                20,
                                19,
                                30,
                              ),
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('img/long_papper.png'),
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              child: _buildPaperContent(),
                            ),
                            SizedBox(height: kBottomNavigationBarHeight + 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 22,
            top: topInset + screenSize.height * 0.01 + 10 * contentScale,
            child: Transform.scale(
              scale: contentScale,
              alignment: Alignment.topLeft,
              child: _BackButton(onTap: backToPast),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  String _toChineseNumber(int number) {
    const List<String> numbers = [
      '',
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '七',
      '八',
      '九',
      '十',
      '十一',
    ];

    if (number >= 1 && number < numbers.length) {
      return numbers[number];
    }

    return number.toString();
  }
}

class _PastPhoto extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final String label;

  const _PastPhoto({this.imageUrl, this.assetPath, required this.label});

  Widget _fallback() {
    return Container(
      color: AppColors.paper,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: _darkBrown),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl ?? '';

    return Container(
      width: 174,
      height: 122,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 9),
      decoration: BoxDecoration(
        color: _photoColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _photoBorder, width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => _fallback(),
                      )
                    : assetPath != null
                    ? Image.asset(assetPath!, fit: BoxFit.cover)
                    : _fallback(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.microBold.copyWith(color: _darkBrown),
          ),
        ],
      ),
    );
  }
}

class _ChapterItem extends StatelessWidget {
  final String number;
  final String title;

  const _ChapterItem({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: AppTextStyles.bodySmallBold.copyWith(color: _darkText),
          ),
          Text(
            '$number：',
            style: AppTextStyles.bodySmallBold.copyWith(color: _darkText),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodySmallBold.copyWith(color: _darkText),
            ),
          ),
        ],
      ),
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
    return GestureDetector(
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
        scale: pressing ? 0.95 : 1,
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

class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
        scale: pressing ? 0.96 : 1,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutBack,
        child: Container(
          width: 225,
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _buttonBorder, width: 2),
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.2),
              radius: 1.15,
              colors: [_buttonCenter, _buttonCenter, _buttonOuter],
              stops: [0, 0.45, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.paper),
          ),
        ),
      ),
    );
  }
}
