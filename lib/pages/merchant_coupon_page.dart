import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _cardColor = AppColors.merchantPaper;
const Color _textColor = AppColors.textPrimary;
const Color _primaryColor = AppColors.primaryDark;
const Color _accentColor = AppColors.primaryAccent;

const Duration _timeout = Duration(seconds: 20);

ButtonStyle _filledStyle([Color color = _primaryColor]) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
  );
}

TextStyle get _whiteButtonText =>
    AppTextStyles.button.copyWith(color: Colors.white);

String _errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

String _numberText(double value) {
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String _two(int number) => number.toString().padLeft(2, '0');

String _formatDay(DateTime date) {
  return '${date.year}/${_two(date.month)}/${_two(date.day)}';
}

String _formatDateTime(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '未設定' : value;

  return '${_formatDay(date)} ${_two(date.hour)}:${_two(date.minute)}';
}

class MerchantCouponPage extends StatefulWidget {
  const MerchantCouponPage({super.key});

  @override
  State<MerchantCouponPage> createState() => _MerchantCouponPageState();
}

class _MerchantCouponPageState extends State<MerchantCouponPage> {
  final String _apiBaseUrl =
      (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com')
          .trim()
          .replaceFirst(RegExp(r'/$'), '');

  List<_Coupon> _coupons = [];
  bool _isLoading = true;
  String? _busyLabel;
  String? _errorMessage;

  bool get _isBusy => _busyLabel != null;

  String get _couponUrl => '$_apiBaseUrl/api/merchant/coupons';
  String get _qrBindUrl => '$_apiBaseUrl/api/merchant/qrcode/bind';

  Map<String, String> get _headers {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入狀態已失效，請重新登入');
    }

    return {
      'accept': '*/*',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return response.body;
    }
  }

  dynamic _unwrap(dynamic body) {
    if (body is! Map) return null;

    return body['Result'] ?? body['result'] ?? body['data'] ?? body['Data'];
  }

  void _checkResponse(http.Response response) {
    final body = _decodeResponse(response);
    final failed =
        response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (body is Map && body['isSuccess'] == false);

    if (!failed) return;

    final message = body is Map
        ? (body['message'] ?? body['Message'] ?? body['detail'])?.toString()
        : null;

    throw Exception(message ?? '操作失敗（HTTP ${response.statusCode}）');
  }

  Future<http.Response> _request(
    String method,
    String url, {
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse(url))
      ..headers.addAll(_headers);

    if (body != null) request.body = jsonEncode(body);

    final response = await http.Response.fromStream(
      await request.send().timeout(_timeout),
    );

    _checkResponse(response);

    return response;
  }

  Future<void> _patchStatus(int couponId, String status) async {
    await _request(
      'PATCH',
      '$_couponUrl/$couponId/status',
      body: {'status': status},
    );
  }

  Future<String> _bindNewQr(int couponId) async {
    final qrUid = const Uuid().v4();

    await _request(
      'POST',
      _qrBindUrl,
      body: {'qr_uid': qrUid, 'coupon_id': couponId},
    );

    return qrUid;
  }

  Future<int> _resolveCouponId(http.Response created, String code) async {
    final body = _decodeResponse(created);
    final data = _unwrap(body) ?? body;

    if (data is Map) {
      final id = int.tryParse('${data['coupon_id'] ?? data['id'] ?? ''}');
      if (id != null) return id;
    }

    await _loadCoupons();

    final ids = _coupons.where((c) => c.code == code).map((c) => c.id);
    if (ids.isEmpty) throw Exception('找不到新優惠券的 ID');

    return ids.reduce((a, b) => a > b ? a : b);
  }

  Future<List<_Coupon>> _deactivateExpiredCoupons(List<_Coupon> coupons) async {
    final now = DateTime.now();
    final updated = <_Coupon>[];

    for (final coupon in coupons) {
      final endDate = DateTime.tryParse(coupon.validTo);

      if (endDate == null || !coupon.isActive) {
        updated.add(coupon);
        continue;
      }

      final rawDate = coupon.validTo.trim();
      final effectiveEndDate =
          (!rawDate.contains('T') && !rawDate.contains(' '))
          ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999)
          : endDate;

      if (effectiveEndDate.isAfter(now)) {
        updated.add(coupon);
        continue;
      }

      try {
        await _patchStatus(coupon.id, 'inactive');
        updated.add(coupon.copyWith(status: 'inactive'));
      } catch (e) {
        updated.add(coupon);
        debugPrint('優惠券 ${coupon.id} 自動下架失敗：${_errorText(e)}');
      }
    }

    return updated;
  }

  Future<void> _loadCoupons() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _request('GET', _couponUrl);
      final decoded = _decodeResponse(response);
      final result = decoded is List ? decoded : _unwrap(decoded);

      if (result is! List) throw Exception('優惠券資料格式錯誤');

      final coupons = await _deactivateExpiredCoupons(
        result
            .whereType<Map>()
            .map((item) => _Coupon.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );

      coupons.sort((a, b) {
        final dateA = DateTime.tryParse(a.validFrom);
        final dateB = DateTime.tryParse(b.validFrom);

        if (dateA == null || dateB == null) {
          return dateA == dateB ? 0 : (dateA == null ? 1 : -1);
        }

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _coupons = coupons;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _errorText(e);
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
          ),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _runAction(
    String label,
    Future<String?> Function() action,
  ) async {
    if (!mounted) return;

    setState(() {
      _busyLabel = label;
      _errorMessage = null;
    });

    String? message;

    try {
      message = await action();
    } catch (e) {
      message = _errorText(e);
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }

    if (message != null) _showMessage(message);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = _primaryColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: AppTextStyles.title.copyWith(color: _textColor),
        ),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消', style: AppTextStyles.button),
          ),
          FilledButton(
            style: _filledStyle(confirmColor),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel, style: _whiteButtonText),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _openCouponForm({_Coupon? coupon}) async {
    if (_isBusy) return;

    final result = await showDialog<_CouponFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CouponFormDialog(coupon: coupon),
    );

    if (result == null || !mounted) return;

    await _saveCoupon(result, coupon: coupon);
  }

  Future<void> _saveCoupon(_CouponFormResult form, {_Coupon? coupon}) async {
    if (_isBusy) return;

    String? newQrUid;

    await _runAction('正在儲存優惠券…', () async {
      final created = await _request(
        coupon == null ? 'POST' : 'PUT',
        coupon == null ? _couponUrl : '$_couponUrl/${coupon.id}',
        body: {
          'coupon_code': form.code,
          'coupon_name': form.name,
          'discount_commodity': form.commodity,
          'discount_type': form.discountType,
          'discount_value': form.discountValue,
          'valid_from': form.validFrom.toIso8601String(),
          'valid_to': form.validTo.toIso8601String(),
        },
      );

      var message = coupon == null ? '優惠券新增成功' : '優惠券修改成功';

      if (coupon == null) {
        try {
          final couponId = await _resolveCouponId(created, form.code);
          newQrUid = await _bindNewQr(couponId);
        } catch (e) {
          message = '優惠券已建立，但 QR 綁定失敗：${_errorText(e)}';
        }
      }

      await _loadCoupons();
      return message;
    });

    final qrUid = newQrUid;
    if (qrUid != null && mounted) await _showQrDialog(form.name, qrUid);
  }

  Future<void> _showQrDialog(String couponName, String qrUid) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => _CouponQrDialog(couponName: couponName, qrUid: qrUid),
    );
  }

  Future<void> _showCouponQr(_Coupon coupon) async {
    if (_isBusy) return;

    if (coupon.hasQr) {
      await _showQrDialog(coupon.name, coupon.qrUid);
      return;
    }

    final confirmed = await _confirm(
      title: '尚未綁定 QR',
      message: '要為「${coupon.name}」產生並綁定 QR 嗎？',
      confirmLabel: '產生並綁定',
    );

    if (!confirmed || !mounted) return;

    String? newQrUid;

    await _runAction('正在綁定 QR…', () async {
      newQrUid = await _bindNewQr(coupon.id);
      await _loadCoupons();
      return 'QR 綁定成功';
    });

    final qrUid = newQrUid;
    if (qrUid != null && mounted) await _showQrDialog(coupon.name, qrUid);
  }

  Future<void> _showCouponDetails(_Coupon coupon) async {
    if (_isBusy) return;

    try {
      final response = await _request('GET', '$_couponUrl/${coupon.id}');
      final decoded = _decodeResponse(response);
      final detailData = _unwrap(decoded) ?? decoded;

      if (detailData is! Map) throw Exception('優惠券詳細資料格式錯誤');

      final detail = _Coupon.fromJson(Map<String, dynamic>.from(detailData));
      final qrUid = detail.hasQr ? detail.qrUid : coupon.qrUid;

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _cardColor,
          surfaceTintColor: Colors.transparent,
          title: Text(
            detail.name,
            style: AppTextStyles.title.copyWith(color: _textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailLine('優惠券編號', '${detail.id}'),
                _detailLine('優惠代碼', detail.code),
                _detailLine('適用商品', detail.commodity),
                _detailLine('優惠類型', detail.typeLabel),
                _detailLine('優惠數值', detail.discountText),
                _detailLine('開始日期', _formatDateTime(detail.validFrom)),
                _detailLine('結束日期', _formatDateTime(detail.validTo)),
                _detailLine('目前狀態', detail.isActive ? '已上架' : '未上架'),
                if (qrUid.isEmpty)
                  _detailLine('QR Code', '尚未綁定')
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _QrBox(data: qrUid, size: 160),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('關閉', style: AppTextStyles.button),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage(_errorText(e));
    }
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppTextStyles.bodySmallBold.copyWith(color: _textColor),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTextStyles.bodySmall.copyWith(color: _textColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCouponStatus(_Coupon coupon) async {
    if (_isBusy) return;

    final activate = !coupon.isActive;
    final actionText = activate ? '上架' : '下架';

    final confirmed = await _confirm(
      title: '$actionText優惠券',
      message: '確定要$actionText「${coupon.name}」嗎？',
      confirmLabel: '確定',
    );

    if (!confirmed || !mounted) return;

    await _runAction('正在更新優惠券狀態…', () async {
      await _patchStatus(coupon.id, activate ? 'active' : 'inactive');
      await _loadCoupons();
      return '優惠券已$actionText';
    });
  }

  Future<void> _deleteCoupon(_Coupon coupon) async {
    if (_isBusy) return;

    final confirmed = await _confirm(
      title: '刪除優惠券',
      message: '確定要刪除「${coupon.name}」嗎？此操作無法復原。',
      confirmLabel: '刪除',
      confirmColor: Colors.red.shade700,
    );

    if (!confirmed || !mounted) return;

    await _runAction('正在刪除優惠券…', () async {
      await _request('DELETE', '$_couponUrl/${coupon.id}');
      await _loadCoupons();
      return '優惠券刪除成功';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _pageColor,
          appBar: AppBar(
            backgroundColor: _pageColor,
            foregroundColor: _textColor,
            elevation: 0,
            title: Text(
              '優惠券管理',
              style: AppTextStyles.title.copyWith(color: _textColor),
            ),
            actions: [
              IconButton(
                tooltip: '重新整理',
                onPressed: _isLoading || _isBusy ? null : _loadCoupons,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isBusy || _isLoading ? null : () => _openCouponForm(),
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('新增優惠券', style: _whiteButtonText),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.confirmation_number_outlined,
                          title: '優惠券總數',
                          value: _isLoading ? '…' : '${_coupons.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.check_circle_outline,
                          title: '已上架',
                          value: _isLoading
                              ? '…'
                              : '${_coupons.where((c) => c.isActive).length}',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildCouponList()),
              ],
            ),
          ),
        ),
        if (_busyLabel != null)
          Positioned.fill(child: _BusyOverlay(label: _busyLabel!)),
      ],
    );
  }

  Widget _buildCouponList() {
    if (_isLoading && _coupons.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    }

    if (_errorMessage != null && _coupons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: _primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: _textColor),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _loadCoupons,
                icon: const Icon(Icons.refresh),
                label: Text('重新載入', style: AppTextStyles.button),
              ),
            ],
          ),
        ),
      );
    }

    if (_coupons.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCoupons,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            const Icon(
              Icons.confirmation_number_outlined,
              size: 58,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '目前沒有優惠券',
                style: AppTextStyles.bodyBold.copyWith(color: _textColor),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '點擊右下角「新增優惠券」開始建立',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _coupons.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final coupon = _coupons[index];

          return _CouponCard(
            coupon: coupon,
            onTap: () => _showCouponDetails(coupon),
            onEdit: () => _openCouponForm(coupon: coupon),
            onToggle: () => _toggleCouponStatus(coupon),
            onDelete: () => _deleteCoupon(coupon),
            onQr: () => _showCouponQr(coupon),
            enabled: !_isBusy,
          );
        },
      ),
    );
  }
}

class _Coupon {
  final int id;
  final String code;
  final String name;
  final String commodity;
  final String discountType;
  final double discountValue;
  final String validFrom;
  final String validTo;
  final String status;
  final String qrUid;

  const _Coupon({
    required this.id,
    required this.code,
    required this.name,
    required this.commodity,
    required this.discountType,
    required this.discountValue,
    required this.validFrom,
    required this.validTo,
    required this.status,
    this.qrUid = '',
  });

  factory _Coupon.fromJson(Map<String, dynamic> json) {
    return _Coupon(
      id: int.tryParse('${json['coupon_id'] ?? 0}') ?? 0,
      code: json['coupon_code']?.toString() ?? '',
      name: json['coupon_name']?.toString() ?? '未命名優惠券',
      commodity: json['discount_commodity']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: double.tryParse('${json['discount_value'] ?? 0}') ?? 0,
      validFrom: json['valid_from']?.toString() ?? '',
      validTo: json['valid_to']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      qrUid: json['qr_uid']?.toString() ?? '',
    );
  }

  _Coupon copyWith({String? status}) {
    return _Coupon(
      id: id,
      code: code,
      name: name,
      commodity: commodity,
      discountType: discountType,
      discountValue: discountValue,
      validFrom: validFrom,
      validTo: validTo,
      status: status ?? this.status,
      qrUid: qrUid,
    );
  }

  bool get hasQr => qrUid.isNotEmpty;

  bool get isAmount {
    final type = discountType.toLowerCase();
    return type == 'amount' || type == 'fixed';
  }

  String get typeLabel => isAmount ? '固定金額折抵' : '百分比折扣';

  String get discountText => isAmount
      ? '\$${_numberText(discountValue)}'
      : '${_numberText(discountValue)}%';

  bool get isActive {
    final value = status.trim().toLowerCase();

    return value == 'active' ||
        value == '上架' ||
        value == '啟用' ||
        value == '已上架' ||
        value == 'enabled' ||
        value == 'published' ||
        value == 'true' ||
        value == '1';
  }
}

class _CouponFormResult {
  final String code;
  final String name;
  final String commodity;
  final String discountType;
  final double discountValue;
  final DateTime validFrom;
  final DateTime validTo;

  const _CouponFormResult({
    required this.code,
    required this.name,
    required this.commodity,
    required this.discountType,
    required this.discountValue,
    required this.validFrom,
    required this.validTo,
  });
}

class _CouponFormDialog extends StatefulWidget {
  final _Coupon? coupon;

  const _CouponFormDialog({this.coupon});

  @override
  State<_CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<_CouponFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _commodityController;
  late final TextEditingController _valueController;

  late String _discountType;
  late DateTime _validFrom;
  late DateTime _validTo;
  String? _dateError;

  @override
  void initState() {
    super.initState();

    final coupon = widget.coupon;

    _codeController = TextEditingController(text: coupon?.code ?? '');
    _nameController = TextEditingController(text: coupon?.name ?? '');
    _commodityController = TextEditingController(text: coupon?.commodity ?? '');
    _valueController = TextEditingController(
      text: coupon == null ? '' : _numberText(coupon.discountValue),
    );

    _discountType = (coupon?.isAmount ?? false) ? 'amount' : 'percent';

    final now = DateTime.now();
    _validFrom =
        DateTime.tryParse(coupon?.validFrom ?? '') ??
        DateTime(now.year, now.month, now.day);
    _validTo =
        DateTime.tryParse(coupon?.validTo ?? '') ??
        DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _commodityController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _validFrom : _validTo,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? '選擇優惠券開始日期' : '選擇優惠券結束日期',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    setState(() {
      _dateError = null;

      if (isStart) {
        _validFrom = DateTime(date.year, date.month, date.day);

        if (_validTo.isBefore(_validFrom)) {
          _validTo = DateTime(date.year, date.month, date.day, 23, 59, 59);
        }
      } else {
        _validTo = DateTime(date.year, date.month, date.day, 23, 59, 59);
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_validTo.isBefore(_validFrom)) {
      setState(() => _dateError = '結束日期不能早於開始日期');
      return;
    }

    Navigator.pop(
      context,
      _CouponFormResult(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        commodity: _commodityController.text.trim(),
        discountType: _discountType,
        discountValue: double.parse(_valueController.text.trim()),
        validFrom: _validFrom,
        validTo: _validTo,
      ),
    );
  }

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTextStyles.bodySmall.copyWith(color: _textColor),
      hintStyle: AppTextStyles.caption.copyWith(color: Colors.black45),
      filled: true,
      fillColor: Colors.white,
      border: _border(Colors.black26),
      enabledBorder: _border(Colors.black26),
      focusedBorder: _border(_primaryColor, 1.5),
      errorBorder: _border(Colors.red),
      focusedErrorBorder: _border(Colors.red, 1.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String emptyMessage,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      style: AppTextStyles.body.copyWith(color: _textColor),
      decoration: _decoration(label, hint: hint),
      textCapitalization: capitalization,
      validator: (value) =>
          value == null || value.trim().isEmpty ? emptyMessage : null,
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _textColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        side: BorderSide(
          color: _dateError == null ? Colors.black26 : Colors.red,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _formatDay(date),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: _textColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.coupon != null;

    return AlertDialog(
      backgroundColor: _cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text(
        isEditing ? '修改優惠券' : '新增優惠券',
        style: AppTextStyles.title.copyWith(color: _textColor),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(
                  controller: _codeController,
                  label: '優惠代碼',
                  hint: '例如 SUMMER10',
                  emptyMessage: '請輸入優惠代碼',
                  capitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _nameController,
                  label: '優惠券名稱',
                  hint: '例如 夏日九折',
                  emptyMessage: '請輸入優惠券名稱',
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _commodityController,
                  label: '適用商品',
                  hint: '例如 全品項',
                  emptyMessage: '請輸入適用商品',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _discountType,
                  style: AppTextStyles.body.copyWith(color: _textColor),
                  decoration: _decoration('優惠類型'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('百分比折扣')),
                    DropdownMenuItem(value: 'amount', child: Text('固定金額折抵')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _discountType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueController,
                  style: AppTextStyles.body.copyWith(color: _textColor),
                  decoration: _decoration(
                    '優惠數值',
                    hint: _discountType == 'percent'
                        ? '例如 10 代表九折'
                        : '例如 50 代表折抵 50 元',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final number = double.tryParse(value?.trim() ?? '');

                    if (number == null || number < 0) return '請輸入有效的數值';

                    if (_discountType == 'percent' && number > 100) {
                      return '百分比不可大於 100';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: '開始日期',
                        date: _validFrom,
                        onTap: () => _chooseDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dateButton(
                        label: '結束日期',
                        date: _validTo,
                        onTap: () => _chooseDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                if (_dateError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _dateError!,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: AppTextStyles.button),
        ),
        FilledButton(
          style: _filledStyle(),
          onPressed: _submit,
          child: Text(isEditing ? '儲存' : '建立', style: _whiteButtonText),
        ),
      ],
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  final String label;

  const _BusyOverlay({required this.label});

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  type: MaterialType.transparency,
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(color: _textColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(2, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(color: _textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.merchantStat.copyWith(
                    color: _textColor,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrBox extends StatelessWidget {
  final String data;
  final double size;
  final double padding;
  final double radius;

  const _QrBox({
    required this.data,
    required this.size,
    this.padding = 10,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black26),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final _Coupon coupon;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onQr;
  final bool enabled;

  const _CouponCard({
    required this.coupon,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onQr,
    this.enabled = true,
  });

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: color == null
          ? null
          : TextButton.styleFrom(foregroundColor: color),
      icon: Icon(icon, size: 17),
      label: Text(label, style: AppTextStyles.captionBold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = coupon.isActive;

    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                offset: Offset(2, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: enabled && coupon.hasQr ? onQr : null,
                    child: coupon.hasQr
                        ? _QrBox(
                            data: coupon.qrUid,
                            size: 34,
                            padding: 4,
                            radius: 10,
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.confirmation_number_outlined,
                              color: _primaryColor,
                              size: 26,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          coupon.code.isEmpty ? '無優惠代碼' : coupon.code,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active ? '已上架' : '未上架',
                      style: AppTextStyles.caption.copyWith(
                        color: active ? Colors.green.shade800 : Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coupon.commodity.isEmpty ? '未設定適用商品' : coupon.commodity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        coupon.discountText,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTextStyles.title.copyWith(
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_formatDateTime(coupon.validFrom)} - ${_formatDateTime(coupon.validTo)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: [
                  _action(Icons.qr_code_2, coupon.hasQr ? 'QR' : '綁定 QR', onQr),
                  _action(Icons.edit_outlined, '修改', onEdit),
                  _action(
                    active
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    active ? '下架' : '上架',
                    onToggle,
                  ),
                  _action(
                    Icons.delete_outline,
                    '刪除',
                    onDelete,
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponQrDialog extends StatefulWidget {
  final String couponName;
  final String qrUid;

  const _CouponQrDialog({required this.couponName, required this.qrUid});

  @override
  State<_CouponQrDialog> createState() => _CouponQrDialogState();
}

class _CouponQrDialogState extends State<_CouponQrDialog> {
  final _boundaryKey = GlobalKey();
  bool _isSaving = false;
  String? _status;
  bool _statusIsError = false;

  Future<Uint8List?> _capturePng() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return data?.buffer.asUint8List();
  }

  Future<void> _download() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _status = null;
    });

    var message = 'QR Code 已儲存到相簿';
    var isError = false;

    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception('產生圖片失敗');

      await Gal.putImageBytes(
        bytes,
        name: 'coupon_qr_${DateTime.now().millisecondsSinceEpoch}',
      );
    } on GalException catch (e) {
      isError = true;
      message = e.type == GalExceptionType.accessDenied
          ? '沒有相簿權限，請到系統設定開啟後再試'
          : '儲存失敗：${e.type.message}';
    } catch (e) {
      isError = true;
      message = '儲存失敗：${_errorText(e)}';
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _status = message;
      _statusIsError = isError;
    });
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    final bytes = await _capturePng();

    if (bytes == null) return;

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: 'coupon_qr.png', mimeType: 'image/png'),
        ],
        text: '${widget.couponName} 優惠券 QR Code',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusIsError
        ? Colors.red.shade700
        : Colors.green.shade800;

    return Dialog(
      backgroundColor: _cardColor,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '優惠券 QR Code',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(color: _textColor),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.couponName,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyBold.copyWith(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QrBox(data: widget.qrUid, size: 200),
                    ],
                  ),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _statusIsError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _status!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '分享',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: _textColor,
                    ),
                    onPressed: _isSaving ? null : _share,
                    icon: const Icon(Icons.share_outlined),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '下載',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: _textColor,
                    ),
                    onPressed: _isSaving ? null : _download,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryColor,
                            ),
                          )
                        : const Icon(Icons.download_outlined),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '關閉',
                    style: _filledStyle(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
