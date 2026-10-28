import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_notice.dart';
import '../core/app_text_styles.dart';
import '../api/nearby_cache.dart';

const Color _pageColor = AppColors.background;
const Color _backColor = AppColors.dangerDark;
const Color _titleColor = Color(0xFF841D0B);
const Color _addressColor = AppColors.secondaryRed;
const Color _tagText = Color(0xFF483425);
const Color _tagBorder = AppColors.postcardLine;
const Color _selectedTagColor = Color(0xFF6B4537);
const Color _selectedTagText = Colors.white;
const Color _bottomPanelColor = Color(0xFFE2D8BD);

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  static const double designWidth = 360;
  static const double designHeight = 640;

  static const double panelTop = 35;
  static const double categoryBarHeight = 50;

  static const double ticketHorizontalPadding = 15;
  static const double ticketSpacing = 12;
  static const double listBottomPadding = 90;

  // =========================
  // 分類
  // =========================

  int selectedCategory = 0;

  final categories = const ['飲食', '景點', '休閒'];

  // =========================
  // API 狀態
  // =========================

  List<_NearbyPlace> places = [];

  bool isLoading = true;

  bool isRefreshing = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _pageColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    loadNearbyPlaces();
  }

  // ============================================================
  // 取得附近景點
  // ============================================================

  Future<void> loadNearbyPlaces({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final List<NearbyPlaceData> loadedPlaces = await NearbyCache.instance
          .refresh();

      if (!mounted) return;

      final List<_NearbyPlace> convertedPlaces = loadedPlaces
          .map(_convertPlace)
          .whereType<_NearbyPlace>()
          .toList();

      setState(() {
        places = convertedPlaces;
        isLoading = false;
        isRefreshing = false;
        errorMessage = null;
      });
    } catch (e) {
      debugPrint('Nearby API Error：$e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        isRefreshing = false;

        if (places.isEmpty) {
          errorMessage = e.toString();
        }
      });
    }
  }

  // ============================================================
  // API 資料轉換
  // ============================================================

  _NearbyPlace? _convertPlace(NearbyPlaceData place) {
    final double? lat = _toDouble(place.lat);
    final double? lon = _toDouble(place.lon);
    final double? distanceM = _toDouble(place.distanceM);

    if (lat == null || lon == null || distanceM == null) {
      debugPrint(
        'Nearby 資料格式錯誤：'
        'title=${place.title}, '
        'lat=${place.lat}, '
        'lon=${place.lon}, '
        'distanceM=${place.distanceM}',
      );

      return null;
    }

    return _NearbyPlace(
      title: place.title,
      time: '營業時間',
      images: const ['img/home_trip.png'],
      tags: getTags(place.title),
      address: '前往地址',
      lat: lat,
      lon: lon,
      distanceM: distanceM,
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim());
  }

  // ============================================================
  // 分類
  //
  // 目前 API 沒有 category，
  // 所以暫時根據景點名稱判斷。
  // ============================================================

  List<String> getTags(String name) {
    final String lowerName = name.toLowerCase();

    // -------------------------
    // 飲食
    // -------------------------

    if (lowerName.contains('夜市') ||
        lowerName.contains('餐廳') ||
        lowerName.contains('餐') ||
        lowerName.contains('小吃') ||
        lowerName.contains('冰品') ||
        lowerName.contains('咖啡') ||
        lowerName.contains('飲食') ||
        lowerName.contains('美食')) {
      return ['飲食'];
    }

    // -------------------------
    // 景點
    // -------------------------

    if (lowerName.contains('公園') ||
        lowerName.contains('步道') ||
        lowerName.contains('景觀') ||
        lowerName.contains('自行車道') ||
        lowerName.contains('橋') ||
        lowerName.contains('森林') ||
        lowerName.contains('生態')) {
      return ['景點'];
    }

    // -------------------------
    // 休閒 / 文化
    // -------------------------

    if (lowerName.contains('藝文') ||
        lowerName.contains('博物館') ||
        lowerName.contains('宮') ||
        lowerName.contains('廟') ||
        lowerName.contains('文化') ||
        lowerName.contains('文創') ||
        lowerName.contains('主題館')) {
      return ['休閒'];
    }

    // -------------------------
    // 無法判斷
    // 預設歸類為景點
    // -------------------------

    return ['景點'];
  }

  // ============================================================
  // 分類篩選
  // ============================================================

  List<_NearbyPlace> get filteredPlaces {
    if (selectedCategory == 0) {
      return places;
    }

    final String category = categories[selectedCategory];

    return places.where((place) => place.tags.contains(category)).toList();
  }

  // ============================================================
  // 距離格式化
  // ============================================================

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // ============================================================
  // 開啟 Google Maps 導航
  // ============================================================

  Future<void> openAddress(_NearbyPlace place) async {
    final Uri googleMapsUrl = Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{'api': '1', 'destination': '${place.lat},${place.lon}'},
    );

    try {
      final bool canOpen = await canLaunchUrl(googleMapsUrl);

      if (!canOpen) {
        throw Exception();
      }

      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;

      AppNotice.show('無法開啟 Google Maps');
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _pageColor)),

          Positioned(
            left: 0,
            right: 0,
            top: panelTop,
            bottom: 0,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: _bottomPanelColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
            ),
          ),

          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Stack(
                  children: [
                    // ==================================================
                    // 景點列表
                    // ==================================================

                    Positioned(
                      left: 0,
                      right: 0,
                      top: panelTop + categoryBarHeight,
                      bottom: 0,
                      child: _buildContent(),
                    ),

                    // ==================================================
                    // 上方分類列
                    // ==================================================
                    Positioned(
                      left: 0,
                      right: 0,
                      top: panelTop,
                      height: categoryBarHeight,
                      child: _TopCategoryBar(
                        categories: categories,
                        selectedIndex: selectedCategory,
                        onCategoryChanged: (index) {
                          setState(() {
                            selectedCategory = index;
                          });
                        },
                        onBack: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 1),
    );
  }

  // ============================================================
  // 內容區域
  // ============================================================

  Widget _buildContent() {
    // ============================================================
    // 第一次進入頁面
    // ============================================================

    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _titleColor));
    }

    // ============================================================
    // 第一次載入失敗，而且目前完全沒有資料
    // ============================================================

    if (errorMessage != null && places.isEmpty) {
      return _buildError();
    }

    // ============================================================
    // 沒有景點
    // ============================================================

    if (filteredPlaces.isEmpty) {
      return _buildEmpty();
    }

    // ============================================================
    // 正常景點列表
    // ============================================================

    return ScrollConfiguration(
      behavior: const _NoScrollbarBehavior(),
      child: RefreshIndicator(
        color: _titleColor,
        backgroundColor: _bottomPanelColor,
        onRefresh: () async {
          if (isRefreshing) {
            return;
          }

          setState(() {
            isRefreshing = true;
          });

          await loadNearbyPlaces(showLoading: false);
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(
            left: ticketHorizontalPadding,
            right: ticketHorizontalPadding,
            top: 0,
            bottom: listBottomPadding,
          ),
          itemCount: filteredPlaces.length,
          itemBuilder: (context, index) {
            final _NearbyPlace place = filteredPlaces[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == filteredPlaces.length - 1 ? 0 : ticketSpacing,
              ),
              child: _NearbyTicket(
                place: place,
                onAddressTap: () => openAddress(place),
                distanceText: formatDistance(place.distanceM),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // API 錯誤畫面
  // ============================================================

  Widget _buildError() {
    return RefreshIndicator(
      color: _titleColor,
      backgroundColor: _bottomPanelColor,
      onRefresh: () => loadNearbyPlaces(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off,
                      size: 42,
                      color: _titleColor,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '無法取得附近景點',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: _titleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '發生未知錯誤，刷新嘗試看看吧><',
                      style: AppTextStyles.bodySmall.copyWith(color: _tagText),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 18),

                    GestureDetector(
                      onTap: () {
                        loadNearbyPlaces();
                      },
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedTagColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '重新載入',
                          style: AppTextStyles.captionBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 無資料
  // ============================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      color: _titleColor,
      backgroundColor: _bottomPanelColor,
      onRefresh: () => loadNearbyPlaces(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Text(
                '附近沒有找到相關景點',
                style: AppTextStyles.bodySmallBold.copyWith(color: _tagText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 上方分類列
// ================================================================

class _TopCategoryBar extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onCategoryChanged;
  final VoidCallback onBack;

  const _TopCategoryBar({
    required this.categories,
    required this.selectedIndex,
    required this.onCategoryChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 18, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackTextButton(onTap: onBack),

          const SizedBox(width: 14),

          Expanded(
            child: Row(
              children: List.generate(
                categories.length,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _CategoryButton(
                      text: categories[index],
                      selected: selectedIndex == index,
                      onTap: () {
                        onCategoryChanged(index);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 返回按鈕
// ================================================================

class _BackTextButton extends StatefulWidget {
  final VoidCallback onTap;

  const _BackTextButton({required this.onTap});

  @override
  State<_BackTextButton> createState() => _BackTextButtonState();
}

class _BackTextButtonState extends State<_BackTextButton> {
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
        scale: pressing ? .95 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            '<< 返回',
            style: AppTextStyles.label.copyWith(color: _backColor),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// 分類按鈕
// ================================================================

class _CategoryButton extends StatefulWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> {
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
        scale: pressing ? .96 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected ? _selectedTagColor : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.selected ? _selectedTagColor : _tagText,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.text,
            style: AppTextStyles.captionBold.copyWith(
              color: widget.selected ? _selectedTagText : _tagText,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// 景點卡片
// ================================================================

class _NearbyTicket extends StatelessWidget {
  final _NearbyPlace place;
  final VoidCallback onAddressTap;
  final String distanceText;

  const _NearbyTicket({
    required this.place,
    required this.onAddressTap,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      height: 166,
      child: Stack(
        children: [
          // --------------------------------------------------------
          // Ticket 背景
          // --------------------------------------------------------

          Positioned.fill(
            child: Image.asset(
              'img/ticket.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),

          // --------------------------------------------------------
          // 景點名稱
          // --------------------------------------------------------
          Positioned(
            top: 12,
            left: 14,
            right: 58,
            child: Text(
              place.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(color: _titleColor),
            ),
          ),

          // --------------------------------------------------------
          // 營業時間
          // --------------------------------------------------------
          Positioned(
            top: 38,
            left: 14,
            child: Text(
              place.time,
              style: AppTextStyles.microLabel.copyWith(color: Colors.black),
            ),
          ),

          // --------------------------------------------------------
          // 距離
          // --------------------------------------------------------
          Positioned(
            top: 38,
            right: 65,
            child: Text(
              distanceText,
              style: AppTextStyles.microLabel.copyWith(color: _addressColor),
            ),
          ),

          // --------------------------------------------------------
          // 圖片
          // --------------------------------------------------------
          Positioned(
            left: 14,
            top: 58,
            width: 205,
            height: 69,
            child: _PhotoRow(images: place.images),
          ),

          // --------------------------------------------------------
          // Tags
          // --------------------------------------------------------
          Positioned(
            left: 14,
            bottom: 13,
            child: Row(
              children: place.tags
                  .map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: _Tag(text: tag),
                    ),
                  )
                  .toList(),
            ),
          ),

          // --------------------------------------------------------
          // 前往地址
          // --------------------------------------------------------
          Positioned(
            right: 66,
            bottom: 14,
            child: _AddressButton(text: place.address, onTap: onAddressTap),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 圖片
// ================================================================

class _PhotoRow extends StatelessWidget {
  final List<String> images;

  const _PhotoRow({required this.images});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        images.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == images.length - 1 ? 0 : 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.asset(
                images[index],
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// Tag
// ================================================================

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tagBorder),
      ),
      child: Text(
        text,
        style: AppTextStyles.microBold.copyWith(color: _tagText),
      ),
    );
  }
}

// ================================================================
// 前往地址按鈕
// ================================================================

class _AddressButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _AddressButton({required this.text, required this.onTap});

  @override
  State<_AddressButton> createState() => _AddressButtonState();
}

class _AddressButtonState extends State<_AddressButton> {
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
        scale: pressing ? .95 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: AppTextStyles.microLabel.copyWith(color: _addressColor),
            ),

            const SizedBox(width: 2),

            Image.asset(
              'img/see_more.png',
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ScrollBehavior
// ================================================================

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// ================================================================
// NearbyPlace
// ================================================================

class _NearbyPlace {
  final String title;

  // 暫時保留，API 尚未提供
  final String time;

  // 暫時使用預設圖片
  final List<String> images;

  // 前端暫時判斷
  final List<String> tags;

  // 顯示「前往地址」
  final String address;

  // API 回傳座標
  final double lat;
  final double lon;

  // API 回傳距離
  final double distanceM;

  const _NearbyPlace({
    required this.title,
    required this.time,
    required this.images,
    required this.tags,
    required this.address,
    required this.lat,
    required this.lon,
    required this.distanceM,
  });
}
