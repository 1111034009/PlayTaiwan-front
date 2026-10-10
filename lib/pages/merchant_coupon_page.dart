import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _cardColor = AppColors.merchantPaper;
const Color _textColor = AppColors.textPrimary;
const Color _primaryColor = AppColors.primaryDark;
const Color _accentColor = AppColors.primaryAccent;

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
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isChangingStatus = false;
  bool _isShowingLoadingDialog = false;
  String? _errorMessage;

  bool get _isBusy => _isSaving || _isDeleting || _isChangingStatus;

  String get _couponUrl => '$_apiBaseUrl/api/merchant/coupons';

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

  /// 檢查已過期的優惠券，並透過既有 API 自動下架。
  Future<List<_Coupon>> _deactivateExpiredCoupons(List<_Coupon> coupons) async {
    final now = DateTime.now();
    final updatedCoupons = <_Coupon>[];

    for (final coupon in coupons) {
      final endDate = DateTime.tryParse(coupon.validTo);

      // 無法解析日期時，不擅自修改狀態。
      if (endDate == null || !coupon.isActive) {
        updatedCoupons.add(coupon);
        continue;
      }

      // 若 API 回傳的日期只有年月日，視為當天結束時才到期。
      final rawDate = coupon.validTo.trim();
      final effectiveEndDate =
          (!rawDate.contains('T') && !rawDate.contains(' '))
          ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999)
          : endDate;

      if (effectiveEndDate.isAfter(now)) {
        updatedCoupons.add(coupon);
        continue;
      }

      try {
        final response = await http
            .patch(
              Uri.parse('$_couponUrl/${coupon.id}/status'),
              headers: _headers,
              body: jsonEncode({'status': 'inactive'}),
            )
            .timeout(const Duration(seconds: 20));

        _checkResponse(response);

        // API 下架成功後，同步更新畫面資料。
        updatedCoupons.add(coupon.copyWith(status: 'inactive'));
      } catch (e) {
        // API 失敗時保留原狀態，下次重新載入時再試。
        updatedCoupons.add(coupon);
        debugPrint('優惠券 ${coupon.id} 自動下架失敗：${_errorText(e)}');
      }
    }

    return updatedCoupons;
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return response.body;
    }
  }

  void _checkResponse(http.Response response) {
    final dynamic body = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = '操作失敗（HTTP ${response.statusCode}）';

      if (body is Map) {
        message =
            body['message']?.toString() ??
            body['Message']?.toString() ??
            body['detail']?.toString() ??
            message;
      }

      throw Exception(message);
    }

    if (body is Map && body['isSuccess'] == false) {
      throw Exception(
        body['message']?.toString() ?? body['Message']?.toString() ?? '操作失敗',
      );
    }
  }

  Future<void> _loadCoupons() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_couponUrl), headers: _headers)
          .timeout(const Duration(seconds: 20));

      _checkResponse(response);

      final dynamic decoded = _decodeResponse(response);
      final dynamic result;

      if (decoded is List) {
        result = decoded;
      } else if (decoded is Map) {
        result =
            decoded['Result'] ??
            decoded['result'] ??
            decoded['data'] ??
            decoded['Data'];

        if (result == null && decoded['isSuccess'] == true) {
          throw Exception('伺服器未回傳優惠券資料');
        }
      } else {
        throw Exception('伺服器回傳格式錯誤');
      }

      if (result is! List) {
        throw Exception('優惠券資料格式錯誤');
      }

      var coupons = result
          .whereType<Map>()
          .map((item) => _Coupon.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      coupons = await _deactivateExpiredCoupons(coupons);
      coupons.sort((a, b) {
        final dateA = DateTime.tryParse(a.validFrom);
        final dateB = DateTime.tryParse(b.validFrom);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

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

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
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

  void _showSavingDialog() {
    if (!mounted || _isShowingLoadingDialog) return;

    _isShowingLoadingDialog = true;

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: _cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.black, width: 1),
          ),
          content: Column(
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
              const SizedBox(height: 18),
              Text(
                '正在儲存優惠券…',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: _textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideSavingDialog() {
    if (!_isShowingLoadingDialog) return;

    _isShowingLoadingDialog = false;

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
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

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    _showSavingDialog();

    try {
      final body = jsonEncode({
        'coupon_code': form.code,
        'coupon_name': form.name,
        'discount_commodity': form.commodity,
        'discount_type': form.discountType,
        'discount_value': form.discountValue,
        'valid_from': form.validFrom.toIso8601String(),
        'valid_to': form.validTo.toIso8601String(),
      });

      final http.Response response;

      if (coupon == null) {
        response = await http
            .post(Uri.parse(_couponUrl), headers: _headers, body: body)
            .timeout(const Duration(seconds: 20));
      } else {
        response = await http
            .put(
              Uri.parse('$_couponUrl/${coupon.id}'),
              headers: _headers,
              body: body,
            )
            .timeout(const Duration(seconds: 20));
      }

      _checkResponse(response);

      _hideSavingDialog();

      if (!mounted) return;

      _showMessage(coupon == null ? '優惠券新增成功' : '優惠券修改成功');

      await _loadCoupons();
    } catch (e) {
      _hideSavingDialog();

      if (mounted) {
        _showMessage(_errorText(e));
      }
    } finally {
      _hideSavingDialog();

      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showCouponDetails(_Coupon coupon) async {
    if (_isBusy) return;

    try {
      final response = await http
          .get(Uri.parse('$_couponUrl/${coupon.id}'), headers: _headers)
          .timeout(const Duration(seconds: 20));

      _checkResponse(response);

      final dynamic result = _decodeResponse(response);
      final dynamic detailData;

      if (result is Map) {
        detailData =
            result['Result'] ??
            result['result'] ??
            result['data'] ??
            result['Data'] ??
            result;
      } else {
        detailData = null;
      }

      if (detailData is! Map) {
        throw Exception('優惠券詳細資料格式錯誤');
      }

      final detail = _Coupon.fromJson(Map<String, dynamic>.from(detailData));

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
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
                _detailLine('優惠類型', detail.discountType),
                _detailLine('優惠數值', _discountText(detail)),
                _detailLine('開始日期', _formatDate(detail.validFrom)),
                _detailLine('結束日期', _formatDate(detail.validTo)),
                _detailLine('目前狀態', detail.status),
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

    final currentlyActive = coupon.isActive;
    final nextStatus = currentlyActive ? 'inactive' : 'active';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          currentlyActive ? '下架優惠券' : '上架優惠券',
          style: AppTextStyles.title.copyWith(color: _textColor),
        ),
        content: Text(
          '確定要${currentlyActive ? '下架' : '上架'}「${coupon.name}」嗎？',
          style: AppTextStyles.body.copyWith(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消', style: AppTextStyles.button),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '確定',
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isChangingStatus = true);

    try {
      final response = await http
          .patch(
            Uri.parse('$_couponUrl/${coupon.id}/status'),
            headers: _headers,
            body: jsonEncode({'status': nextStatus}),
          )
          .timeout(const Duration(seconds: 20));

      _checkResponse(response);

      if (!mounted) return;

      _showMessage(currentlyActive ? '優惠券已下架' : '優惠券已上架');
      await _loadCoupons();
    } catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) {
        setState(() => _isChangingStatus = false);
      }
    }
  }

  Future<void> _deleteCoupon(_Coupon coupon) async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '刪除優惠券',
          style: AppTextStyles.title.copyWith(color: _textColor),
        ),
        content: Text(
          '確定要刪除「${coupon.name}」嗎？此操作無法復原。',
          style: AppTextStyles.body.copyWith(color: _textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消', style: AppTextStyles.button),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '刪除',
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .delete(Uri.parse('$_couponUrl/${coupon.id}'), headers: _headers)
          .timeout(const Duration(seconds: 20));

      _checkResponse(response);

      if (!mounted) return;

      _showMessage('優惠券刪除成功');
      await _loadCoupons();
    } catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.isEmpty ? '未設定' : value;

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _discountText(_Coupon coupon) {
    if (coupon.discountType.toLowerCase() == 'percent') {
      return '${_numberText(coupon.discountValue)}%';
    }

    return '\$${_numberText(coupon.discountValue)}';
  }

  String _numberText(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
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
            label: Text(
              '新增優惠券',
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
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
        if (_isDeleting || _isChangingStatus)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
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
                        Text(
                          _isDeleting ? '正在刪除優惠券…' : '正在更新優惠券狀態…',
                          style: AppTextStyles.body.copyWith(color: _textColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
            dateFormatter: _formatDate,
            discountText: _discountText(coupon),
            onTap: () => _showCouponDetails(coupon),
            onEdit: () => _openCouponForm(coupon: coupon),
            onToggle: () => _toggleCouponStatus(coupon),
            onDelete: () => _deleteCoupon(coupon),
            enabled: !_isBusy,
          );
        },
      ),
    );
  }
}

class _Coupon {
  final int id;
  final int storeId;
  final String code;
  final String name;
  final String commodity;
  final String discountType;
  final double discountValue;
  final String validFrom;
  final String validTo;
  final String status;

  const _Coupon({
    required this.id,
    required this.storeId,
    required this.code,
    required this.name,
    required this.commodity,
    required this.discountType,
    required this.discountValue,
    required this.validFrom,
    required this.validTo,
    required this.status,
  });

  factory _Coupon.fromJson(Map<String, dynamic> json) {
    return _Coupon(
      id: int.tryParse('${json['coupon_id'] ?? 0}') ?? 0,
      storeId: int.tryParse('${json['s_id'] ?? 0}') ?? 0,
      code: json['coupon_code']?.toString() ?? '',
      name: json['coupon_name']?.toString() ?? '未命名優惠券',
      commodity: json['discount_commodity']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: double.tryParse('${json['discount_value'] ?? 0}') ?? 0,
      validFrom: json['valid_from']?.toString() ?? '',
      validTo: json['valid_to']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
  _Coupon copyWith({String? status}) {
    return _Coupon(
      id: id,
      storeId: storeId,
      code: code,
      name: name,
      commodity: commodity,
      discountType: discountType,
      discountValue: discountValue,
      validFrom: validFrom,
      validTo: validTo,
      status: status ?? this.status,
    );
  }

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

    final type = coupon?.discountType.toLowerCase() ?? '';
    _discountType = type == 'amount' || type == 'fixed' ? 'amount' : 'percent';

    final now = DateTime.now();
    _validFrom =
        DateTime.tryParse(coupon?.validFrom ?? '') ??
        DateTime(now.year, now.month, now.day);
    _validTo =
        DateTime.tryParse(coupon?.validTo ?? '') ??
        DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  String _numberText(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
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
    final initial = isStart ? _validFrom : _validTo;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('結束日期不能早於開始日期')));
      return;
    }

    final value = double.tryParse(_valueController.text.trim());

    if (value == null || value < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入有效的優惠數值')));
      return;
    }

    if (_discountType == 'percent' && value > 100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('百分比不可大於 100')));
      return;
    }

    Navigator.pop(
      context,
      _CouponFormResult(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        commodity: _commodityController.text.trim(),
        discountType: _discountType,
        discountValue: value,
        validFrom: _validFrom,
        validTo: _validTo,
      ),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    );
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
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
        side: const BorderSide(color: Colors.black26),
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
                  _formatDate(date),
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
                TextFormField(
                  controller: _codeController,
                  style: AppTextStyles.body.copyWith(color: _textColor),
                  decoration: _decoration('優惠代碼', hint: '例如 SUMMER10'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入優惠代碼';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  style: AppTextStyles.body.copyWith(color: _textColor),
                  decoration: _decoration('優惠券名稱', hint: '例如 夏日九折'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入優惠券名稱';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commodityController,
                  style: AppTextStyles.body.copyWith(color: _textColor),
                  decoration: _decoration('適用商品', hint: '例如 全品項'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入適用商品';
                    }
                    return null;
                  },
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
                    if (value != null) {
                      setState(() => _discountType = value);
                    }
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

                    if (number == null || number < 0) {
                      return '請輸入有效的數值';
                    }

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
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(
            isEditing ? '儲存' : '建立',
            style: AppTextStyles.button.copyWith(color: Colors.white),
          ),
        ),
      ],
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

class _CouponCard extends StatelessWidget {
  final _Coupon coupon;
  final String Function(String) dateFormatter;
  final String discountText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool enabled;

  const _CouponCard({
    required this.coupon,
    required this.dateFormatter,
    required this.discountText,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.enabled = true,
  });

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
                  Container(
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
                        discountText,
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
                      '${dateFormatter(coupon.validFrom)} - ${dateFormatter(coupon.validTo)}',
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
                  TextButton.icon(
                    onPressed: enabled ? onEdit : null,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: Text('修改', style: AppTextStyles.captionBold),
                  ),
                  TextButton.icon(
                    onPressed: enabled ? onToggle : null,
                    icon: Icon(
                      active
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 17,
                    ),
                    label: Text(
                      active ? '下架' : '上架',
                      style: AppTextStyles.captionBold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: enabled ? onDelete : null,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: Text('刪除', style: AppTextStyles.captionBold),
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
