import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../block/navigationbar.dart';
import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

enum _Filter { all, unused, used, expired }

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const Color _pageColor = AppColors.background;
  static const Color _red = AppColors.primaryAccent;
  static const Color _darkText = AppColors.textPrimary;
  static const Color _darkBrown = AppColors.darkBrown;
  static const Color _paper = Color(0xFFF7F0DF);

  int currentIndex = 0;

  List<Map<String, dynamic>> _items = [];
  _Filter _filter = _Filter.all;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};
  final Set<String> _stampAnimate = {};
  String get _baseUrl {
    final String url = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return url.replaceFirst(RegExp(r'/$'), '');
  }

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

    _load();
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Map<String, dynamic> _coupon(Map<String, dynamic> item) {
    final dynamic raw = item['coupon'];

    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  bool _isUsed(Map<String, dynamic> item) => item['is_used'] == true;

  bool _isExpired(Map<String, dynamic> item) {
    if (_isUsed(item)) return false;

    final DateTime? to = DateTime.tryParse(_text(_coupon(item)['valid_to']));

    if (to != null && to.isBefore(DateTime.now())) return true;

    return item['is_usable'] == false;
  }

  bool _isUnused(Map<String, dynamic> item) =>
      !_isUsed(item) && !_isExpired(item);

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _Filter.unused:
        return _items.where(_isUnused).toList();
      case _Filter.used:
        return _items.where(_isUsed).toList();
      case _Filter.expired:
        return _items.where(_isExpired).toList();
      case _Filter.all:
        return _items;
    }
  }

  int _count(_Filter filter) {
    switch (filter) {
      case _Filter.unused:
        return _items.where(_isUnused).length;
      case _Filter.used:
        return _items.where(_isUsed).length;
      case _Filter.expired:
        return _items.where(_isExpired).length;
      case _Filter.all:
        return _items.length;
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = '登入資訊已失效，請重新登入';
      });
      return;
    }

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/api/coupons'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('取得優惠券失敗：HTTP ${response.statusCode}');
      }

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data is! Map || data['isSuccess'] != true) {
        throw Exception(data is Map ? _text(data['message']) : '取得優惠券失敗');
      }

      final dynamic result = data['Result'];

      final List<Map<String, dynamic>> items = result is List
          ? result
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : [];

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (showLoading || _items.isEmpty) {
          _error = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  Future<void> _redeem(Map<String, dynamic> item) async {
    final Map<String, dynamic> coupon = _coupon(item);
    final String id = _text(coupon['coupon_id']);

    if (id.isEmpty || _busy.contains(id)) return;

    final bool ok = await _confirmRedeem(coupon, _text(item['store_name']));

    if (!ok || !mounted) return;

    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      _snack('登入資訊已失效，請重新登入');
      return;
    }

    setState(() {
      _busy.add(id);
    });

    try {
      final bool success =
          await showGeneralDialog<bool>(
            context: context,
            barrierDismissible: false,
            barrierLabel: '核銷中',
            barrierColor: AppColors.dialogBarrier,
            transitionDuration: const Duration(milliseconds: 280),
            transitionBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              );

              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
            pageBuilder: (context, animation, secondaryAnimation) {
              return Center(
                child: _RedeemDialog(
                  couponName: _text(coupon['coupon_name']),
                  task: () => _requestRedeem(id, token),
                ),
              );
            },
          ) ??
          false;

      if (success) {
        _stampAnimate.add(id);
        await _load(showLoading: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(id);
        });
      }
    }
  }

  /// 回傳 null 代表成功，否則回傳錯誤訊息
  Future<String?> _requestRedeem(String id, String token) async {
    try {
      final http.Response response = await http.post(
        Uri.parse('$_baseUrl/api/coupons/$id/redeem'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );

      dynamic data;

      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }

      final bool success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map &&
          data['isSuccess'] == true;

      if (success) return null;

      final String message = data is Map ? _text(data['message']) : '';

      return message.isEmpty ? '核銷失敗，請稍後再試' : message;
    } catch (_) {
      return '請探員確認連線~';
    }
  }

  Future<bool> _confirmRedeem(
    Map<String, dynamic> coupon,
    String storeName,
  ) async {
    final String couponName = _text(coupon['coupon_name']);

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.warmPaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.postcardLine, width: 1.5),
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.warning_amber_rounded, color: _red),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '確認要使用「$couponName」優惠券？',
                  style: AppTextStyles.title.copyWith(color: _darkText),
                ),
              ),
            ],
          ),
          content: Text(
            '本操作無法復原或取消，請您在結帳前主動出示後並按下確認核銷。',
            style: AppTextStyles.bodySmallBold.copyWith(
              color: _darkBrown,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                '下次再用',
                style: AppTextStyles.bodyBold.copyWith(color: _darkBrown),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                '確認核銷',
                style: AppTextStyles.bodyBold.copyWith(color: _red),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _snack(String message) {
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

  String _discountText(Map<String, dynamic> coupon) {
    final dynamic value = coupon['discount_value'];
    final String commodity = _text(coupon['discount_commodity']);

    String discount = '';

    if (value is num) {
      final String shown = value == value.truncate()
          ? value.toInt().toString()
          : value.toString();

      discount = _text(coupon['discount_type']) == 'percent'
          ? '折扣 $shown%'
          : '折抵 $shown 元';
    }

    return [commodity, discount].where((e) => e.isNotEmpty).join('・');
  }

  String _date(dynamic value) {
    final DateTime? date = DateTime.tryParse(_text(value));

    if (date == null) return '';

    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');

    return '${date.year}/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: AppNavigationBar(currentIndex: currentIndex),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _darkText,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              '我的錢包',
              style: AppTextStyles.titleLarge.copyWith(color: _darkText),
            ),
          ),
          const Icon(Icons.local_activity_rounded, color: _red, size: 26),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const labels = {
      _Filter.all: '全部',
      _Filter.unused: '未使用',
      _Filter.used: '已使用',
      _Filter.expired: '已過期',
    };

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final _Filter f in _Filter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _filter == f ? _red : AppColors.warmPaper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filter == f
                          ? AppColors.primaryDark
                          : AppColors.postcardLine,
                      width: 1.3,
                    ),
                  ),
                  child: Text(
                    '${labels[f]} ${_count(f)}',
                    style: AppTextStyles.captionBold.copyWith(
                      color: _filter == f ? Colors.white : _darkBrown,
                    ),
                  ),
                ),
              ),
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

    final List<Map<String, dynamic>> list = _filtered;

    if (list.isEmpty) {
      return _buildMessage(
        icon: Icons.local_activity_outlined,
        message: _items.isEmpty ? '還沒有優惠券\n完成劇本任務就能獲得' : '這個分類目前沒有優惠券',
      );
    }

    return RefreshIndicator(
      color: _red,
      onRefresh: () => _load(showLoading: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildCard(list[index]),
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
            Icon(icon, size: 46, color: _darkBrown.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.mutedText,
                height: 1.6,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: _load,
                child: Text(
                  action,
                  style: AppTextStyles.bodyBold.copyWith(color: _red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final Map<String, dynamic> coupon = _coupon(item);
    final bool used = _isUsed(item);
    final bool expired = _isExpired(item);
    final bool active = !used && !expired;
    final String id = _text(coupon['coupon_id']);
    final bool busy = _busy.contains(id);

    final String store = _text(item['store_name']);
    final String address = _text(item['full_address']);
    final String image = _text(item['image_url']);
    final String discount = _discountText(coupon);
    final String from = _date(coupon['valid_from']);
    final String to = _date(coupon['valid_to']);

    final Color accent = active ? _red : const Color(0xFF8B837B);
    final String stateText = used ? '已使用' : (expired ? '已過期' : '可使用');

    final Widget card = Opacity(
      opacity: active ? 1 : 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.postcardLine, width: 1.3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(2, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              color: accent,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(coupon['coupon_name']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyEmphasisBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        if (discount.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            discount,
                            style: AppTextStyles.captionBold.copyWith(
                              color: const Color(0xFFFFE3A2),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Text(
                      stateText,
                      style: AppTextStyles.microBold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: image.isEmpty
                          ? _imageFallback()
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _imageFallback(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _darkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _infoRow(Icons.location_on_rounded, address),
                        const SizedBox(height: 3),
                        _infoRow(
                          Icons.schedule_rounded,
                          to.isEmpty
                              ? ''
                              : (from.isEmpty ? '至 $to' : '$from ~ $to'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.postcardLine,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _text(coupon['coupon_code']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyBold.copyWith(
                                color: accent,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: _text(coupon['coupon_code']),
                                ),
                              );

                              _snack('已複製優惠碼');
                            },
                            child: Icon(
                              Icons.copy_rounded,
                              size: 17,
                              color: _darkBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: active && !busy ? () => _redeem(item) : null,
                    child: Container(
                      width: 92,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppColors.primaryDark
                              : const Color(0xFFB8B0A6),
                          width: 1.5,
                        ),
                        gradient: active
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primary,
                                ],
                              )
                            : null,
                        color: active ? null : const Color(0xFFDAD3C8),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              active ? '使用' : stateText,
                              style: AppTextStyles.captionBold.copyWith(
                                color: active
                                    ? Colors.white
                                    : const Color(0xFF8B837B),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!used) return card;

    return Stack(
      children: [
        card,
        Positioned(
          right: 14,
          top: 50,
          child: IgnorePointer(
            child: _StampOverlay(
              key: ValueKey('stamp_$id'),
              animate: _stampAnimate.contains(id),
              onDone: () => _stampAnimate.remove(id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.questionBackground,
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_rounded,
        color: _darkBrown.withValues(alpha: 0.6),
        size: 28,
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _red),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: _darkBrown,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _StampOverlay extends StatefulWidget {
  final bool animate;
  final double size;
  final VoidCallback? onDone;

  const _StampOverlay({
    super.key,
    required this.animate,
    this.size = 110,
    this.onDone,
  });

  @override
  State<_StampOverlay> createState() => _StampOverlayState();
}

class _StampOverlayState extends State<_StampOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 2.6,
        end: 0.92,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.92,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
  ]).animate(_c);

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();

    if (widget.animate) {
      _c.forward().whenComplete(() => widget.onDone?.call());

      // 印章落下的瞬間給一下震動
      Future.delayed(const Duration(milliseconds: 390), () {
        if (mounted) HapticFeedback.mediumImpact();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value * 0.92,
          child: Transform.rotate(
            angle: -0.22,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
      child: Image.asset(
        'img/stamp_2.png',
        width: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }
}

enum _RedeemPhase { working, done, failed }

/// 核銷中 → 成功蓋章 / 失敗 的遊戲風彈窗
class _RedeemDialog extends StatefulWidget {
  final String couponName;
  final Future<String?> Function() task;

  const _RedeemDialog({required this.couponName, required this.task});

  @override
  State<_RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<_RedeemDialog>
    with SingleTickerProviderStateMixin {
  _RedeemPhase _phase = _RedeemPhase.working;
  String _errorText = '';
  bool _closed = false;

  late final AnimationController _swing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _swing.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    // 至少顯示約 1.1 秒，避免 API 太快時動畫一閃而過
    final List<String?> results = await Future.wait<String?>([
      widget.task(),
      Future<String?>.delayed(const Duration(milliseconds: 1100), () => null),
    ]);

    if (!mounted) return;

    final String? error = results.first;

    _swing.stop();

    if (error == null) {
      setState(() => _phase = _RedeemPhase.done);

      await Future.delayed(const Duration(milliseconds: 2200));

      _close(true);
    } else {
      setState(() {
        _phase = _RedeemPhase.failed;
        _errorText = error;
      });
    }
  }

  void _close(bool result) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(result);
  }

  String get _title {
    switch (_phase) {
      case _RedeemPhase.working:
        return '核銷中…';
      case _RedeemPhase.done:
        return '核銷成功！';
      case _RedeemPhase.failed:
        return '核銷失敗';
    }
  }

  Widget _buildMiddle() {
    switch (_phase) {
      case _RedeemPhase.working:
        return Column(
          key: const ValueKey('working'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _swing,
              builder: (context, child) => Transform.rotate(
                angle: (_swing.value - 0.5) * 0.6,
                child: child,
              ),
              child: const Icon(
                Icons.local_activity_rounded,
                size: 72,
                color: AppColors.primaryAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '店家確認中，請稍候',
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFF6F6258),
              ),
            ),
          ],
        );
      case _RedeemPhase.done:
        return Column(
          key: const ValueKey('done'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StampOverlay(animate: true, size: 110),
            const SizedBox(height: 4),
            Text(
              widget.couponName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.darkBrown,
              ),
            ),
          ],
        );
      case _RedeemPhase.failed:
        return Column(
          key: const ValueKey('failed'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.primaryAccent,
            ),
            const SizedBox(height: 8),
            Text(
              _errorText,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmallBold.copyWith(
                color: AppColors.darkBrown,
                height: 1.5,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width < 340
        ? MediaQuery.of(context).size.width - 30
        : 310;

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          height: 310,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset('img/set_papper.png', fit: BoxFit.fill),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
                child: Column(
                  children: [
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildMiddle(),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: _phase == _RedeemPhase.working
                          ? null
                          : GestureDetector(
                              onTap: () => _close(_phase == _RedeemPhase.done),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: AppColors.primaryAccent,
                                  border: Border.all(
                                    color: const Color(0xFF551308),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x55000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _phase == _RedeemPhase.done ? '完成' : '知道了',
                                  style: AppTextStyles.button.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
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
