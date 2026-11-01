import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/merchant_browse_api.dart';
import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../core/app_text_styles.dart';
import '../core/story_generation.dart';
import '../core/taiwan_districts.dart';

/// 逛逛商家（遊客瀏覽商家與優惠券）：GET /api/Merchant/Browse。
/// 可以依縣市、行政區、關鍵字、「只看有優惠券」篩選，往下滑自動載入下一頁。
/// 等劇本生成的時候進來，會自動帶劇本的縣市、行政區（[StoryGeneration.city] / [StoryGeneration.town]）
class MerchantBrowsePage extends StatefulWidget {
  const MerchantBrowsePage({super.key, this.initialCity, this.initialTown});

  final String? initialCity;
  final String? initialTown;

  @override
  State<MerchantBrowsePage> createState() => _MerchantBrowsePageState();
}

class _MerchantBrowsePageState extends State<MerchantBrowsePage> {
  static const Color _pageColor = AppColors.background;
  static const Color _red = AppColors.primaryAccent;
  static const Color _darkText = AppColors.textPrimary;
  static const int _pageSize = 20;

  int currentIndex = 0;

  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _city;
  String? _town;
  bool _onlyWithCoupon = false;

  final List<BrowseStore> _items = [];
  int _total = 0;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// 連續查詢時只採用最後一次的結果
  int _seq = 0;

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

    _applyInitialArea();
    _scrollController.addListener(_onScroll);
    _search();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 預設的縣市、行政區：先看呼叫的人有沒有給，沒有再看「劇本生成中」的縣市、行政區
  void _applyInitialArea() {
    final StoryGeneration gen = StoryGeneration.instance;

    String? city = widget.initialCity;
    String? town = widget.initialTown;

    if ((city ?? '').trim().isEmpty && gen.active) {
      city = gen.city;
      town = gen.town;
    }

    city = MerchantBrowseApi.normalizeCity(city ?? '');

    if (!taiwanDistricts.containsKey(city)) return;

    _city = city;

    final String t = MerchantBrowseApi.normalizeCity(town ?? '');

    _town = taiwanDistricts[city]!.contains(t) ? t : null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final ScrollPosition p = _scrollController.position;

    if (p.pixels >= p.maxScrollExtent - 240) _loadMore();
  }

  Future<void> _search() async {
    final int seq = ++_seq;

    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });

    try {
      final BrowsePage result = await MerchantBrowseApi.browse(
        city: _city,
        town: _town,
        keyword: _keywordController.text,
        onlyWithCoupon: _onlyWithCoupon,
        page: 1,
        pageSize: _pageSize,
      );

      if (!mounted || seq != _seq) return;

      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _total = result.total;
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;

      setState(() {
        _items.clear();
        _total = 0;
        _hasMore = false;
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;

    final int seq = _seq;

    setState(() => _loadingMore = true);

    try {
      final BrowsePage result = await MerchantBrowseApi.browse(
        city: _city,
        town: _town,
        keyword: _keywordController.text,
        onlyWithCoupon: _onlyWithCoupon,
        page: _page + 1,
        pageSize: _pageSize,
      );

      if (!mounted || seq != _seq) return;

      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _page = result.page;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;

      // 下一頁失敗：停在目前的結果，讓使用者按「載入更多」再試
      setState(() => _loadingMore = false);
    }
  }

  // ───────────────────────────── 畫面 ─────────────────────────────

  /// 平板（最短邊 ≥ 600）：內容置中放寬到 1040、字放大、商家排成兩欄；
  /// 手機維持原本的單欄（SafeFrame）
  bool get _isTablet => MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: [
        _buildHeader(),
        _buildFilterPanel(),
        Expanded(child: _buildBody()),
      ],
    );

    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: _isTablet
          ? SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.15)),
                    child: content,
                  ),
                ),
              ),
            )
          : SafeFrame(bottom: false, child: content),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Text(
                '<< 返回',
                style: AppTextStyles.bodySmallBold.copyWith(color: _red),
              ),
            ),
          ),
          const Spacer(),

          const Icon(Icons.storefront_rounded, color: _red, size: 26),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    final List<String> towns = _city == null
        ? const []
        : taiwanDistricts[_city!] ?? const [];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.postcardLine, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AreaDropdown(
                  hint: '縣市',
                  emptyLabel: '全部縣市',
                  value: _city,
                  items: taiwanDistricts.keys.toList(),
                  onChanged: (v) {
                    setState(() {
                      _city = v;
                      _town = null;
                    });
                    _search();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AreaDropdown(
                  hint: '行政區',
                  emptyLabel: '全部行政區',
                  value: _town,
                  items: towns,
                  enabled: _city != null,
                  onChanged: (v) {
                    setState(() => _town = v);
                    _search();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.inputLine, width: 1.2),
                  ),
                  child: TextField(
                    controller: _keywordController,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center, // 垂直置中
                    onSubmitted: (_) => _search(),
                    cursorColor: _red,
                    style: AppTextStyles.bodyCompact.copyWith(color: _darkText),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '搜尋店名、店家介紹',
                      hintStyle: AppTextStyles.bodyCompact.copyWith(
                        color: AppColors.inputHint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _PressButton(
                onTap: _search,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: AppColors.darkBorder, width: 1.6),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _onlyWithCoupon = !_onlyWithCoupon);
                  _search();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _onlyWithCoupon ? _red : AppColors.warmPaper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _onlyWithCoupon
                          ? AppColors.primaryDark
                          : AppColors.postcardLine,
                      width: 1.3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_activity_rounded,
                        size: 16,
                        color: _onlyWithCoupon
                            ? Colors.white
                            : AppColors.darkBrown,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '只看有優惠券',
                        style: AppTextStyles.captionBold.copyWith(
                          color: _onlyWithCoupon
                              ? Colors.white
                              : AppColors.darkBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (!_loading && _error == null)
                Text(
                  '共 $_total 間',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.softBrown,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _red));
    }

    if (_error != null) {
      return _buildMessage(
        icon: Icons.error_outline_rounded,
        message: _error!,
        action: '重新載入',
      );
    }

    if (_items.isEmpty) {
      return _buildMessage(
        icon: Icons.storefront_outlined,
        message: '這個條件下找不到商家\n換個縣市或關鍵字試試',
      );
    }

    // 平板兩欄、手機一欄
    final int cols = _isTablet ? 2 : 1;
    final int rows = (_items.length + cols - 1) ~/ cols;

    return RefreshIndicator(
      color: _red,
      onRefresh: _search,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        itemCount: rows + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= rows) return _buildMoreFooter();

          if (cols == 1) {
            final BrowseStore store = _items[index];

            return _StoreCard(store: store, onTap: () => _showDetail(store));
          }

          final List<Widget> cells = [];

          for (int c = 0; c < cols; c++) {
            final int i = index * cols + c;

            cells.add(
              Expanded(
                child: i < _items.length
                    ? _StoreCard(
                        store: _items[i],
                        onTap: () => _showDetail(_items[i]),
                      )
                    : const SizedBox.shrink(),
              ),
            );

            if (c < cols - 1) cells.add(const SizedBox(width: 12));
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoreFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _red),
              )
            : TextButton(
                onPressed: _loadMore,
                child: Text(
                  '載入更多',
                  style: AppTextStyles.bodySmallBold.copyWith(color: _red),
                ),
              ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    String? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 46,
              color: AppColors.darkBrown.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.paper,
                height: 1.6,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: _search,
                child: Text(
                  action,
                  style: AppTextStyles.bodySmallBold.copyWith(color: _red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BrowseStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      constraints: BoxConstraints(
        maxWidth: _isTablet ? 760 : 640,
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StoreDetail(store: store),
    );
  }
}

// ───────────────────────────── 小元件 ─────────────────────────────

String _zhDay(String day) {
  const Map<String, String> names = {
    'monday': '週一',
    'tuesday': '週二',
    'wednesday': '週三',
    'thursday': '週四',
    'friday': '週五',
    'saturday': '週六',
    'sunday': '週日',
  };

  return names[day.toLowerCase()] ?? day;
}

String _hourText(BrowseHour? h) {
  if (h == null) return '未提供營業時間';

  if (h.openTime == '00:00' && h.closeTime == '23:59') return '24 小時營業';

  return '${h.openTime} – ${h.closeTime}';
}

String _dateText(DateTime? d) {
  if (d == null) return '';

  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');

  return '${d.year}/$m/$day';
}

class _AreaDropdown extends StatelessWidget {
  final String hint;
  final String emptyLabel;
  final String? value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _AreaDropdown({
    required this.hint,
    required this.emptyLabel,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : AppColors.warmPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputLine, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          isDense: true,
          value: value,
          menuMaxHeight: 320,
          hint: Text(
            hint,
            style: AppTextStyles.bodyCompact.copyWith(
              color: AppColors.mutedText,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
          style: AppTextStyles.bodyCompactBold.copyWith(
            color: AppColors.textPrimary,
          ),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(emptyLabel)),
            for (final String item in items)
              DropdownMenuItem<String?>(value: item, child: Text(item)),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _PressButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressButton({required this.onTap, required this.child});

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: pressing ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  final String url;
  final double size;

  const _StoreImage({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: size,
      height: size,
      color: AppColors.warmPaper,
      child: Icon(
        Icons.storefront_rounded,
        size: size * 0.45,
        color: AppColors.postcardLine,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            ),
    );
  }
}

class _CouponChip extends StatelessWidget {
  final BrowseCoupon coupon;

  const _CouponChip({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryAccent, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_activity_rounded,
            size: 13,
            color: AppColors.primaryAccent,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${coupon.discountText}・${coupon.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.microBold.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final BrowseStore store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final List<BrowseCoupon> shown = store.coupons.take(2).toList();
    final int more = store.coupons.length - shown.length;

    return _PressButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.postcardLine, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x45000000),
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StoreImage(url: store.imageUrl, size: 84),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (store.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          store.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.softBrown,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.mutedText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              store.address.isEmpty
                                  ? '${store.city}${store.town}'
                                  : store.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.micro.copyWith(
                                color: AppColors.mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.mutedText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '今日 ${_hourText(store.today)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.micro.copyWith(
                                color: AppColors.mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final BrowseCoupon c in shown) _CouponChip(coupon: c),
                  if (more > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        '還有 $more 張',
                        style: AppTextStyles.microBold.copyWith(
                          color: AppColors.softBrown,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreDetail extends StatelessWidget {
  final BrowseStore store;

  const _StoreDetail({required this.store});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.postcardLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (store.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    store.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.warmPaper),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              store.name,
              style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
            ),
            if (store.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                store.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.softBrown,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.primaryAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    store.address.isEmpty
                        ? '${store.city}${store.town}'
                        : store.address,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '營業時間',
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
            const SizedBox(height: 4),
            if (store.hours.isEmpty)
              Text(
                '未提供營業時間',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedText,
                ),
              )
            else
              for (final BrowseHour h in store.hours)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          _zhDay(h.dayOfWeek),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.softBrown,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _hourText(h),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 14),
            Text(
              '優惠券（${store.coupons.length}）',
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
            const SizedBox(height: 6),
            if (store.coupons.isEmpty)
              Text(
                '目前沒有優惠券',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.mutedText,
                ),
              )
            else
              for (final BrowseCoupon c in store.coupons)
                _CouponTile(coupon: c),
          ],
        ),
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  final BrowseCoupon coupon;

  const _CouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final String period = coupon.validTo == null
        ? ''
        : '有效期限 ${_dateText(coupon.validFrom)} – ${_dateText(coupon.validTo)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.postcardLine, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              coupon.discountText,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.name,
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (coupon.commodity.isNotEmpty)
                  Text(
                    '適用：${coupon.commodity}',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.softBrown,
                    ),
                  ),
                if (period.isNotEmpty)
                  Text(
                    period,
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          if (coupon.isUsed || coupon.isClaimed) ...[
            const SizedBox(width: 6),
            Text(
              coupon.isUsed ? '已使用' : '已領取',
              style: AppTextStyles.microBold.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
