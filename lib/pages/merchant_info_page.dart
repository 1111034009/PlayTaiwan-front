import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api/merchant_register_api.dart';
import '../core/app_colors.dart';
import '../core/app_session.dart';
import '../core/app_text_styles.dart';

const Color _pageColor = AppColors.background;
const Color _paperColor = AppColors.card;
const Color _paperBorder = Color(0xFF000000);
const Color _darkText = AppColors.textPrimary;
const Color _bodyText = Color(0xFF2F2D28);

const Color _buttonBorder = AppColors.primaryDark;
const Color _buttonCenter = AppColors.primaryLight;
const Color _buttonOuter = AppColors.primary;

const Color _accentRed = AppColors.deepRed;

class MerchantInfoPage extends StatefulWidget {
  const MerchantInfoPage({super.key});

  @override
  State<MerchantInfoPage> createState() => _MerchantInfoPageState();
}

class _MerchantInfoPageState extends State<MerchantInfoPage> {
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  OverlayEntry? _activeSnackBarEntry;
  Timer? _snackBarTimer;

  String accountName = AppSession.epName ?? '';
  String shopName = '';
  String shopDescription = '';
  String shopAddress = '';
  String shopCity = '';
  String shopTown = '';
  String shopCategory = '';
  String shopSubCategory = '';
  String shopImageUrl = '';
  bool shopIsSelfBuilt = false;
  List<OperatingHour> shopHours = [];

  double? shopLat;
  double? shopLng;

  bool isMerchantLoading = true;

  @override
  void dispose() {
    _snackBarTimer?.cancel();

    if (_activeSnackBarEntry?.mounted ?? false) {
      _activeSnackBarEntry!.remove();
    }

    _activeSnackBarEntry = null;

    super.dispose();
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

    _loadCachedMerchantProfile();

    unawaited(_fetchProfile());
    unawaited(_fetchMerchantProfile());
  }

  void _loadCachedMerchantProfile() {
    final cached = AppSession.merchantProfile;
    if (cached == null) return;

    _applyMerchantProfile(cached, updateSession: false);
    isMerchantLoading = false;
  }

  void _readProfile(Map<String, dynamic> profile) {
    shopName = profile['store_name']?.toString() ?? '';
    shopDescription = profile['store_dec']?.toString() ?? '';
    shopAddress = profile['store_address']?.toString() ?? '';
    shopCity = profile['store_city']?.toString() ?? '';
    shopTown = profile['store_town']?.toString() ?? '';
    shopCategory = profile['category']?.toString() ?? '';
    shopSubCategory = profile['sub_category']?.toString() ?? '';
    shopImageUrl = profile['image_url']?.toString().trim() ?? '';
    shopIsSelfBuilt = profile['is_self_built_place'] == true;

    final dynamic lat = profile['lat'];
    final dynamic lng = profile['lng'];

    shopLat = lat is num ? lat.toDouble() : double.tryParse('$lat');
    shopLng = lng is num ? lng.toDouble() : double.tryParse('$lng');

    final dynamic hours = profile['operating_hours'];

    shopHours = hours is List
        ? hours
              .whereType<Map>()
              .map(
                (h) => OperatingHour(
                  dayOfWeek: h['day_of_week']?.toString() ?? '',
                  openTime: h['open_time']?.toString() ?? '',
                  closeTime: h['close_time']?.toString() ?? '',
                ),
              )
              .toList()
        : [];
  }

  void _applyMerchantProfile(
    Map<String, dynamic> data, {
    bool updateSession = true,
  }) {
    if (updateSession) {
      AppSession.updateMerchantProfile(data);
    }

    final Map<String, dynamic> profile = {
      ...?AppSession.merchantProfile,
      ...data,
    };

    if (!mounted) {
      _readProfile(profile);
      return;
    }

    setState(() {
      _readProfile(profile);
    });
  }

  Future<void> _fetchProfile() async {
    final token = AppSession.token;

    if (token == null || token.isEmpty || _apiBaseUrl.isEmpty) return;

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/api/Auth/Profile'),
            headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> || decoded['isSuccess'] != true) {
        return;
      }

      final result = decoded['Result'];

      final String? name = result is Map ? result['ep_name']?.toString() : null;

      if (name != null && name.isNotEmpty && mounted) {
        setState(() {
          accountName = name;
          AppSession.epName = name;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMerchantProfile() async {
    final token = AppSession.token;

    if (token == null || token.isEmpty || _apiBaseUrl.isEmpty) {
      if (mounted) {
        setState(() {
          isMerchantLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/api/Merchant/Profile'),
            headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic> &&
          decoded['isSuccess'] == true &&
          decoded['Result'] is Map) {
        final result = Map<String, dynamic>.from(decoded['Result'] as Map);

        if (!mounted) return;

        _applyMerchantProfile(result);
      } else if (mounted) {
        _showSnackBar(
          decoded is Map
              ? decoded['message']?.toString() ?? '取得店家資訊失敗'
              : '取得店家資訊失敗',
        );
      }
    } on TimeoutException {
      if (mounted && AppSession.merchantProfile == null) {
        _showSnackBar('取得店家資訊逾時，請稍後再試');
      }
    } catch (_) {
      if (mounted && AppSession.merchantProfile == null) {
        _showSnackBar('無法連線到伺服器');
      }
    } finally {
      if (mounted) {
        setState(() {
          isMerchantLoading = false;
        });
      }
    }
  }

  Future<bool> _updateProfile(String epName) async {
    final String newName = epName.trim();

    if (newName.isEmpty) {
      _showSnackBar('帳號名稱不可為空');
      return false;
    }

    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      _showSnackBar('登入資訊已失效，請重新登入');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/Auth/Profile'),
            headers: {
              'accept': 'text/plain',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'auth_name': newName}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return false;

        setState(() {
          accountName = newName;
          AppSession.epName = newName;
        });

        return true;
      }

      if (mounted) _showSnackBar('更新帳號名稱失敗');

      return false;
    } catch (_) {
      if (mounted) _showSnackBar('無法連線到伺服器');

      return false;
    }
  }

  Future<bool> _changePassword(String oldPassword, String newPassword) async {
    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      _showSnackBar('登入資訊已失效，請重新登入');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/Auth/ChangePassword'),
            headers: {
              'accept': 'text/plain',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'OldPassword': oldPassword,
              'NewPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      if (mounted) _showSnackBar('修改密碼失敗');

      return false;
    } catch (_) {
      if (mounted) _showSnackBar('無法連線到伺服器');

      return false;
    }
  }

  /// 只送有變動的欄位；沒帶的欄位後端維持原值
  Future<bool> _updateMerchantProfile(Map<String, dynamic> fields) async {
    if (fields.isEmpty) return true;

    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      _showSnackBar('登入資訊已失效，請重新登入');
      return false;
    }

    try {
      final response = await http
          .put(
            Uri.parse('$_apiBaseUrl/api/Merchant/Profile'),
            headers: {
              'accept': '*/*',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      final bool failed =
          response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['isSuccess'] == false;

      if (failed) {
        final String message = data['message']?.toString().trim() ?? '';

        if (mounted) {
          _showSnackBar(message.isEmpty ? '更新店家資訊失敗' : message);
        }

        return false;
      }

      return true;
    } on TimeoutException {
      if (mounted) _showSnackBar('更新逾時，請稍後再試');

      return false;
    } catch (_) {
      if (mounted) _showSnackBar('無法連線到伺服器');

      return false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    _snackBarTimer?.cancel();

    if (_activeSnackBarEntry?.mounted ?? false) {
      _activeSnackBarEntry!.remove();
    }
    _activeSnackBarEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        final mediaQuery = MediaQuery.of(overlayContext);

        return Positioned(
          left: 16,
          right: 16,
          bottom: mediaQuery.padding.bottom + 16,
          child: Material(
            color: Colors.transparent,
            child: _TopSnackBar(
              message: message,
              onClose: () {
                if (entry.mounted) {
                  entry.remove();
                }

                if (identical(_activeSnackBarEntry, entry)) {
                  _activeSnackBarEntry = null;
                  _snackBarTimer?.cancel();
                }
              },
            ),
          ),
        );
      },
    );

    _activeSnackBarEntry = entry;
    overlay.insert(entry);

    _snackBarTimer = Timer(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }

      if (identical(_activeSnackBarEntry, entry)) {
        _activeSnackBarEntry = null;
      }
    });
  }

  Future<void> editAccount() async {
    final result = await showDialog<_AccountEditResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xDD000000),
      builder: (dialogContext) {
        return _AccountEditDialog(initialAccountName: accountName);
      },
    );

    if (!mounted || result == null) return;

    final String newAccountName = result.accountName.trim();
    final String oldPassword = result.oldPassword;
    final String newPassword = result.newPassword;

    if (newAccountName.isEmpty) {
      _showSnackBar('帳號名稱不可為空');
      return;
    }

    final bool nameChanged = newAccountName != accountName;
    final bool oldPasswordEntered = oldPassword.isNotEmpty;
    final bool newPasswordEntered = newPassword.isNotEmpty;

    if (oldPasswordEntered != newPasswordEntered) {
      _showSnackBar('原密碼與新密碼都必須填寫才可修改');
      return;
    }

    if (!nameChanged && !oldPasswordEntered && !newPasswordEntered) {
      return;
    }

    if (nameChanged) {
      final bool success = await _updateProfile(newAccountName);

      if (!success) return;
    }

    if (oldPasswordEntered && newPasswordEntered) {
      final bool success = await _changePassword(oldPassword, newPassword);

      if (!success) return;
    }

    if (mounted) {
      _showSnackBar('帳號資料更新成功');
    }
  }

  Future<void> editShop() async {
    final result = await showDialog<_MerchantEditResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xDD000000),
      builder: (dialogContext) {
        return _MerchantEditDialog(
          initialName: shopName,
          initialDescription: shopDescription,
          initialAddress: _fullAddress,
          initialCity: shopCity,
          initialTown: shopTown,
          initialLat: shopLat,
          initialLng: shopLng,
          initialImageUrl: shopImageUrl,
          initialCategory: shopCategory,
          initialSubCategory: shopSubCategory,
          initialHours: shopHours,
          isSelfBuilt: shopIsSelfBuilt,
        );
      },
    );

    if (!mounted || result == null) return;

    final Map<String, dynamic> fields = {};

    final String newName = result.name.trim();
    final String newDescription = result.description.trim();

    if (newName != shopName) {
      fields['store_name'] = newName;
    }

    if (newDescription != shopDescription) {
      fields['store_dec'] = newDescription;
    }

    final String newFullAddress = _joinAddress(
      result.city,
      result.town,
      result.address,
    );

    final bool addressChanged = newFullAddress != _fullAddress;

    if (addressChanged) {
      if (!result.addressConfirmed ||
          result.lat == null ||
          result.lng == null) {
        _showSnackBar('請先確認地址');
        return;
      }

      fields['store_address'] = result.address;
      fields['store_city'] = result.city;
      fields['store_town'] = result.town;
      fields['lat'] = result.lat;
      fields['lng'] = result.lng;
    }

    if (result.imageUrl != shopImageUrl) {
      fields['image_url'] = result.imageUrl;
    }

    if (shopIsSelfBuilt) {
      if (result.category.isNotEmpty && result.category != shopCategory) {
        fields['category'] = result.category;
      }

      if (result.subCategory != null && result.subCategory != shopSubCategory) {
        fields['sub_category'] = result.subCategory;
      }

      if (_hoursKey(result.hours) != _hoursKey(shopHours)) {
        fields['operating_hours'] = result.hours
            .map((OperatingHour h) => h.toJson())
            .toList();
      }
    }

    if (fields.isEmpty) return;

    final bool success = await _updateMerchantProfile(fields);

    if (!success || !mounted) return;

    final List<OperatingHour> newHours = fields.containsKey('operating_hours')
        ? result.hours
        : shopHours;

    final updatedProfile = <String, dynamic>{
      ...?AppSession.merchantProfile,
      'store_name': newName,
      'store_dec': newDescription,
      'store_address': addressChanged ? result.address : shopAddress,
      'store_city': addressChanged ? result.city : shopCity,
      'store_town': addressChanged ? result.town : shopTown,
      'lat': addressChanged ? result.lat : shopLat,
      'lng': addressChanged ? result.lng : shopLng,
      'image_url': result.imageUrl,
      'category': fields.containsKey('category')
          ? result.category
          : shopCategory,
      'sub_category': fields.containsKey('sub_category')
          ? result.subCategory
          : (fields.containsKey('category') ? '' : shopSubCategory),
      'operating_hours': newHours.map((OperatingHour h) => h.toJson()).toList(),
    };

    _applyMerchantProfile(updatedProfile);

    _showSnackBar('店家資訊更新成功');

    // 以後端資料為準（類別更換後的細分類等）
    unawaited(_fetchMerchantProfile());
  }

  String get _fullAddress => _joinAddress(shopCity, shopTown, shopAddress);

  Future<void> logout() async {
    final token = AppSession.token;

    AppSession.clear();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);

    if (token == null || token.isEmpty) return;

    try {
      await http.post(
        Uri.parse('$_apiBaseUrl/api/Auth/Logout'),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 560),
        child: SizedBox(
          width: 360,
          child: _InfoCard(
            accountName: accountName,
            shopName: shopName,
            shopDescription: shopDescription,
            shopAddress: _fullAddress,
            category: shopCategory,
            subCategory: shopSubCategory,
            imageUrl: shopImageUrl,
            hours: shopHours,
            isLoading: isMerchantLoading && AppSession.merchantProfile == null,
            onEditAccount: editAccount,
            onEditShop: editShop,
            onLogout: logout,
          ),
        ),
      ),
    );
  }
}

class _AccountEditResult {
  final String accountName;
  final String oldPassword;
  final String newPassword;

  const _AccountEditResult({
    required this.accountName,
    required this.oldPassword,
    required this.newPassword,
  });
}

class _AccountEditDialog extends StatefulWidget {
  final String initialAccountName;

  const _AccountEditDialog({required this.initialAccountName});

  @override
  State<_AccountEditDialog> createState() => _AccountEditDialogState();
}

class _AccountEditDialogState extends State<_AccountEditDialog> {
  late final TextEditingController accountController;
  late final TextEditingController oldPasswordController;
  late final TextEditingController newPasswordController;

  @override
  void initState() {
    super.initState();

    accountController = TextEditingController(text: widget.initialAccountName);

    oldPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    accountController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();

    super.dispose();
  }

  void submit() {
    final String accountName = accountController.text.trim();

    if (accountName.isEmpty) return;

    Navigator.pop(
      context,
      _AccountEditResult(
        accountName: accountName,
        oldPassword: oldPasswordController.text,
        newPassword: newPasswordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      child: Container(
        width: 310,
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),
        decoration: BoxDecoration(
          color: _paperColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.black, width: 1.3),
          boxShadow: const [
            BoxShadow(
              color: _darkText,
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '編輯帳號資料',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.black,
                  height: 1,
                ),
              ),
              const SizedBox(height: 18),
              _AccountTextField(
                controller: accountController,
                label: '帳號名稱',
                obscureText: false,
              ),
              const SizedBox(height: 12),
              _AccountTextField(
                controller: oldPasswordController,
                label: '原通行密碼',
                obscureText: true,
              ),
              const SizedBox(height: 12),
              _AccountTextField(
                controller: newPasswordController,
                label: '新通行密碼',
                obscureText: true,
              ),
              const SizedBox(height: 18),
              _DialogActions(
                onCancel: () => Navigator.pop(context),
                onSave: submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;

  const _AccountTextField({
    required this.controller,
    required this.label,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLength: 30,
      textAlign: TextAlign.center,
      style: AppTextStyles.subtitle.copyWith(color: _bodyText),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: AppTextStyles.captionBold.copyWith(
          color: const Color(0xFF6F6258),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: _accentRed, width: 2),
        ),
      ),
    );
  }
}

class _MerchantEditResult {
  final String name;
  final String description;
  final String address;
  final String city;
  final String town;
  final double? lat;
  final double? lng;
  final bool addressConfirmed;
  final String imageUrl;
  final String category;
  final String? subCategory;
  final List<OperatingHour> hours;

  const _MerchantEditResult({
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.town,
    required this.lat,
    required this.lng,
    required this.addressConfirmed,
    required this.imageUrl,
    required this.category,
    required this.subCategory,
    required this.hours,
  });
}

class _HourRow {
  String day;
  String open;
  String close;

  _HourRow({required this.day, this.open = '09:00', this.close = '18:00'});
}

class _MerchantEditDialog extends StatefulWidget {
  final String initialName;
  final String initialDescription;
  final String initialAddress;
  final String initialCity;
  final String initialTown;
  final double? initialLat;
  final double? initialLng;
  final String initialImageUrl;
  final String initialCategory;
  final String initialSubCategory;
  final List<OperatingHour> initialHours;
  final bool isSelfBuilt;

  const _MerchantEditDialog({
    required this.initialName,
    required this.initialDescription,
    required this.initialAddress,
    required this.initialCity,
    required this.initialTown,
    required this.initialLat,
    required this.initialLng,
    required this.initialImageUrl,
    required this.initialCategory,
    required this.initialSubCategory,
    required this.initialHours,
    required this.isSelfBuilt,
  });

  @override
  State<_MerchantEditDialog> createState() => _MerchantEditDialogState();
}

class _MerchantEditDialogState extends State<_MerchantEditDialog> {
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static const List<MerchantCategory> _fallbackCategories = [
    MerchantCategory(
      category: 'Attraction',
      name: '景點',
      defaultSubCategory: '其他',
      subCategories: [],
    ),
    MerchantCategory(
      category: 'Restaurant',
      name: '餐廳',
      defaultSubCategory: '其他',
      subCategories: [],
    ),
    MerchantCategory(
      category: 'Hotel',
      name: '住宿',
      defaultSubCategory: null,
      subCategories: [],
    ),
    MerchantCategory(
      category: 'Event',
      name: '活動',
      defaultSubCategory: '一般活動',
      subCategories: [],
    ),
  ];

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController addressController;

  late String city;
  late String town;

  double? lat;
  double? lng;

  bool addressConfirmed = true;
  bool isGeocoding = false;

  late String imageUrl;
  bool isUploadingImage = false;

  late String category;
  String? subCategory;
  List<MerchantCategory> categories = [];
  String? categoriesError;

  final List<_HourRow> hourRows = [];
  String? hoursError;

  String? message;
  bool messageIsError = true;

  List<MerchantCategory> get _categoryList =>
      categories.isNotEmpty ? categories : _fallbackCategories;

  bool get _hasValidCategory =>
      _categoryList.any((MerchantCategory c) => c.category == category);

  MerchantCategory get _currentCategory => _categoryList.firstWhere(
    (MerchantCategory c) => c.category == category,
    orElse: () => _categoryList.first,
  );

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.initialName);

    descriptionController = TextEditingController(
      text: widget.initialDescription,
    );

    addressController = TextEditingController(text: widget.initialAddress);

    city = widget.initialCity;
    town = widget.initialTown;
    lat = widget.initialLat;
    lng = widget.initialLng;

    imageUrl = widget.initialImageUrl;
    category = widget.initialCategory;
    subCategory = widget.initialSubCategory.isEmpty
        ? null
        : widget.initialSubCategory;

    for (final OperatingHour h in widget.initialHours) {
      hourRows.add(
        _HourRow(day: h.dayOfWeek, open: h.openTime, close: h.closeTime),
      );
    }

    addressController.addListener(_onAddressChanged);

    if (widget.isSelfBuilt) _loadCategories();
  }

  @override
  void dispose() {
    addressController.removeListener(_onAddressChanged);

    nameController.dispose();
    descriptionController.dispose();
    addressController.dispose();

    super.dispose();
  }

  void _onAddressChanged() {
    final String currentAddress = addressController.text.trim();

    if (currentAddress != widget.initialAddress &&
        (addressConfirmed || lat != null || lng != null)) {
      setState(() {
        addressConfirmed = false;
        lat = null;
        lng = null;
      });
    }
  }

  void _showMessage(String text, {bool error = true}) {
    if (!mounted) return;

    setState(() {
      message = text;
      messageIsError = error;
    });
  }

  Future<void> _loadCategories() async {
    try {
      final List<MerchantCategory> list =
          await MerchantRegisterApi.fetchCategories();

      if (!mounted) return;

      setState(() {
        categories = list;
        categoriesError = null;

        if (subCategory != null &&
            !_currentCategory.subCategories.contains(subCategory)) {
          subCategory = null;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        categoriesError = '細分類載入失敗，暫時無法選擇細分類';
      });
    }
  }

  Future<void> _pickImage() async {
    if (isUploadingImage) return;

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (file == null || !mounted) return;

    setState(() {
      isUploadingImage = true;
      message = null;
    });

    try {
      final String url = await MerchantRegisterApi.uploadImage(file);

      if (!mounted) return;

      setState(() {
        imageUrl = url;
      });
    } catch (e) {
      _showMessage('圖片上傳失敗：${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
      }
    }
  }

  String? _checkHours() {
    return OperatingHour.validate(_currentHours());
  }

  List<OperatingHour> _currentHours() {
    return _sortedHours(
      hourRows
          .map(
            (_HourRow r) => OperatingHour(
              dayOfWeek: r.day,
              openTime: r.open,
              closeTime: r.close,
            ),
          )
          .toList(),
    );
  }

  void _addHourRow() {
    final _HourRow? last = hourRows.isEmpty ? null : hourRows.last;

    final int nextDay = last == null
        ? 0
        : (OperatingHour.days.indexOf(last.day) + 1) % 7;

    setState(() {
      hourRows.add(
        _HourRow(
          day: OperatingHour.days[nextDay],
          open: last?.open ?? '09:00',
          close: last?.close ?? '18:00',
        ),
      );
      hoursError = _checkHours();
    });
  }

  Future<void> _pickTime(_HourRow row, {required bool isOpen}) async {
    final List<String> parts = (isOpen ? row.open : row.close).split(':');

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    final String text =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (isOpen) {
        row.open = text;
      } else {
        row.close = text;
      }

      hoursError = _checkHours();
    });
  }

  Map<String, String>? _splitAddress(String input) {
    String value = input
        .trim()
        .replaceAll('　', '')
        .replaceAll('台', '臺')
        .replaceAll('０', '0')
        .replaceAll('１', '1')
        .replaceAll('２', '2')
        .replaceAll('３', '3')
        .replaceAll('４', '4')
        .replaceAll('５', '5')
        .replaceAll('６', '6')
        .replaceAll('７', '7')
        .replaceAll('８', '8')
        .replaceAll('９', '9');

    value = value.replaceFirst(RegExp(r'^(中華民國|臺灣|台灣)'), '');

    const cities = [
      '臺北市',
      '新北市',
      '桃園市',
      '臺中市',
      '臺南市',
      '高雄市',
      '基隆市',
      '新竹市',
      '嘉義市',
      '新竹縣',
      '苗栗縣',
      '彰化縣',
      '南投縣',
      '雲林縣',
      '嘉義縣',
      '屏東縣',
      '宜蘭縣',
      '花蓮縣',
      '臺東縣',
      '澎湖縣',
      '金門縣',
      '連江縣',
    ];

    String? foundCity;

    for (final cityName in cities) {
      if (value.startsWith(cityName)) {
        foundCity = cityName;
        break;
      }
    }

    if (foundCity == null) return null;

    value = value.substring(foundCity.length);

    final townMatch = RegExp(r'^(.{1,6}?(?:區|鄉|鎮|市))').firstMatch(value);

    if (townMatch == null) return null;

    final String foundTown = townMatch.group(1)!;

    final String foundAddress = value.substring(foundTown.length).trim();

    if (foundAddress.isEmpty) return null;

    final bool hasAddressKeyword = RegExp(
      r'(路|街|大道|巷|弄|號|段)',
    ).hasMatch(foundAddress);

    final bool hasNumber = RegExp(r'\d').hasMatch(foundAddress);

    if (!hasAddressKeyword || !hasNumber) return null;

    return {'city': foundCity, 'town': foundTown, 'address': foundAddress};
  }

  Future<void> _confirmAddress() async {
    final String input = addressController.text.trim();

    if (input.isEmpty) {
      _showMessage('請輸入完整地址');
      return;
    }

    if (_apiBaseUrl.isEmpty) {
      _showMessage('尚未設定 API_BASE_URL');
      return;
    }

    final parsed = _splitAddress(input);

    if (parsed == null) {
      _showMessage('請輸入完整地址，例如：台中市北屯區三民路三段201巷29號');
      return;
    }

    setState(() {
      isGeocoding = true;
      addressConfirmed = false;
      lat = null;
      lng = null;
      message = null;
    });

    try {
      final uri =
          Uri.parse(
            '$_apiBaseUrl/api/merchant/register/address-to-location',
          ).replace(
            queryParameters: {
              'store_city': parsed['city']!,
              'store_town': parsed['town']!,
              'store_address': parsed['address']!,
            },
          );

      final response = await http
          .get(uri, headers: {'accept': 'text/plain'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _showMessage('地址轉換失敗（HTTP ${response.statusCode}），請稍後再試');
        return;
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        _showMessage('地址轉換 API 回傳格式錯誤');
        return;
      }

      if (decoded['isSuccess'] != true) {
        _showMessage(decoded['message']?.toString() ?? '地址轉換失敗');
        return;
      }

      final dynamic result = decoded['Result'];

      if (result is! Map) {
        _showMessage('地址轉換 API 未回傳座標資料');
        return;
      }

      final double? resultLat = double.tryParse('${result['lat']}');

      final double? resultLng = double.tryParse('${result['lng']}');

      if (resultLat == null ||
          resultLng == null ||
          resultLat < -90 ||
          resultLat > 90 ||
          resultLng < -180 ||
          resultLng > 180) {
        _showMessage('API 未回傳有效的經緯度');
        return;
      }

      if (!mounted) return;

      if (addressController.text.trim() != input) {
        _showMessage('地址已變更，請重新確認地址');
        return;
      }

      setState(() {
        city = parsed['city']!;
        town = parsed['town']!;
        lat = resultLat;
        lng = resultLng;
        addressConfirmed = true;
        message = null;
      });
    } on TimeoutException {
      _showMessage('地址查詢逾時，請稍後再試');
    } catch (_) {
      _showMessage('地址轉換失敗，請確認網路連線或稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          isGeocoding = false;
        });
      }
    }
  }

  void _submit() {
    final String name = nameController.text.trim();
    final String address = addressController.text.trim();

    if (name.isEmpty) {
      _showMessage('店家名稱不可為空');
      return;
    }

    if (isUploadingImage) {
      _showMessage('照片上傳中，請稍候');
      return;
    }

    List<OperatingHour> hours = widget.initialHours;

    if (widget.isSelfBuilt) {
      final String? error = _checkHours();

      if (error != null) {
        setState(() {
          hoursError = error;
        });
        _showMessage(error);
        return;
      }

      hours = _currentHours();
    }

    final bool addressChanged = address != widget.initialAddress;

    String resultAddress = widget.initialAddress;
    String resultCity = widget.initialCity;
    String resultTown = widget.initialTown;

    if (addressChanged) {
      if (!addressConfirmed || lat == null || lng == null) {
        _showMessage('修改地址後，請先按「確認地址」');
        return;
      }

      final parsed = _splitAddress(address);

      if (parsed == null) {
        _showMessage('請輸入完整地址');
        return;
      }

      resultAddress = parsed['address']!;
      resultCity = parsed['city']!;
      resultTown = parsed['town']!;
    }

    Navigator.pop(
      context,
      _MerchantEditResult(
        name: name,
        description: descriptionController.text.trim(),
        address: resultAddress,
        city: resultCity,
        town: resultTown,
        lat: addressChanged ? lat : widget.initialLat,
        lng: addressChanged ? lng : widget.initialLng,
        addressConfirmed: true,
        imageUrl: imageUrl,
        category: category,
        subCategory: subCategory,
        hours: hours,
      ),
    );
  }

  InputDecoration _dropDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.captionBold.copyWith(
        color: const Color(0xFF6F6258),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.black, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: Colors.black, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: _accentRed, width: 2),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '店家照片',
          style: AppTextStyles.captionBold.copyWith(
            color: const Color(0xFF6F6258),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isUploadingImage ? null : _pickImage,
          child: Container(
            height: 130,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: isUploadingImage
                ? const Center(child: CircularProgressIndicator())
                : imageUrl.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 34,
                        color: Color(0xFF6F6258),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '點擊選擇照片',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF6F6258),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => imageUrl = ''),
                          child: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _timeButton(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _bodyText,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: const BorderSide(color: Colors.black, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Text(
        text,
        style: AppTextStyles.captionBold.copyWith(color: _bodyText),
      ),
    );
  }

  Widget _buildHourRow(int index) {
    final _HourRow row = hourRows[index];
    final bool nextDay = row.close.compareTo(row.open) <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ObjectKey(row),
                  initialValue: row.day,
                  isExpanded: true,
                  decoration: _dropDecoration('星期'),
                  style: AppTextStyles.subtitle.copyWith(color: _bodyText),
                  items: [
                    for (final String d in OperatingHour.days)
                      DropdownMenuItem(
                        value: d,
                        child: Text(OperatingHour.dayLabels[d]!),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) return;

                    setState(() {
                      row.day = value;
                      hoursError = _checkHours();
                    });
                  },
                ),
              ),
              IconButton(
                tooltip: '刪除時段',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    hourRows.removeAt(index);
                    hoursError = _checkHours();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Expanded(
                  child: _timeButton(
                    row.open,
                    () => _pickTime(row, isOpen: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '~',
                    style: AppTextStyles.captionBold.copyWith(color: _bodyText),
                  ),
                ),
                Expanded(
                  child: _timeButton(
                    row.close,
                    () => _pickTime(row, isOpen: false),
                  ),
                ),
              ],
            ),
          ),
          if (nextDay)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Text(
                  '結束時間為隔天',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.deepOrange,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHoursEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '營業時間',
          style: AppTextStyles.captionBold.copyWith(
            color: const Color(0xFF6F6258),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '公休日不用填；中午休息請同一天填兩段；跨夜營業的結束時間會算隔天。全部刪除並儲存會清空營業時間。',
          style: AppTextStyles.caption.copyWith(color: const Color(0xFF6F6258)),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < hourRows.length; i++) _buildHourRow(i),
        if (hoursError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              hoursError!,
              style: AppTextStyles.caption.copyWith(color: Colors.redAccent),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addHourRow,
            icon: const Icon(Icons.add),
            label: Text(
              '新增時段',
              style: AppTextStyles.captionBold.copyWith(color: _accentRed),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentRed,
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Colors.black, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    final MerchantCategory current = _currentCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _hasValidCategory ? category : null,
          isExpanded: true,
          decoration: _dropDecoration('店家類別'),
          style: AppTextStyles.subtitle.copyWith(color: _bodyText),
          items: [
            for (final MerchantCategory c in _categoryList)
              DropdownMenuItem(value: c.category, child: Text(c.name)),
          ],
          onChanged: (String? value) {
            if (value == null) return;

            setState(() {
              category = value;
              subCategory = null;
            });
          },
        ),
        if (categoriesError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              categoriesError!,
              style: AppTextStyles.caption.copyWith(color: Colors.deepOrange),
            ),
          ),
        if (_hasValidCategory && current.subCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('sub_$category'),
            initialValue: subCategory,
            isExpanded: true,
            menuMaxHeight: 320,
            decoration: _dropDecoration('細分類'),
            style: AppTextStyles.subtitle.copyWith(color: _bodyText),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  category == widget.initialCategory ? '不變更' : '使用預設',
                ),
              ),
              for (final String s in current.subCategories)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: (String? value) {
              setState(() {
                subCategory = value;
              });
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        width: 360,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),
        decoration: BoxDecoration(
          color: _paperColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.black, width: 1.3),
          boxShadow: const [
            BoxShadow(
              color: _darkText,
              blurRadius: 0,
              spreadRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '編輯店家資訊',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.black,
                  height: 1,
                ),
              ),
              const SizedBox(height: 20),
              _MerchantTextField(
                controller: nameController,
                label: '店家名稱',
                maxLines: 1,
              ),
              const SizedBox(height: 14),
              _MerchantTextField(
                controller: descriptionController,
                label: '店家介紹',
                maxLines: 4,
              ),
              const SizedBox(height: 14),
              _MerchantTextField(
                controller: addressController,
                label: '完整地址（縣市、區、路段、巷弄、門牌號碼）',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isGeocoding ? null : _confirmAddress,
                  icon: isGeocoding
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.location_on),
                  label: Text(isGeocoding ? '正在確認地址...' : '確認地址'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _buttonOuter,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                  ),
                ),
              ),
              if (addressConfirmed && lat != null && lng != null) ...[
                const SizedBox(height: 8),
                Text(
                  '地址已確認',
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.green.shade800,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildImageSection(),
              const SizedBox(height: 16),
              if (widget.isSelfBuilt) ...[
                _buildCategorySection(),
                const SizedBox(height: 16),
                _buildHoursEditor(),
              ] else
                Text(
                  '此店家綁定的是既有景點，類別與營業時間由景點資料決定，無法在這裡修改。',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF6F6258),
                  ),
                ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: AppTextStyles.captionBold.copyWith(
                    color: messageIsError
                        ? Colors.red.shade700
                        : Colors.green.shade800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _DialogActions(
                onCancel: () => Navigator.pop(context),
                onSave: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _MerchantTextField({
    required this.controller,
    required this.label,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: 300,
      style: AppTextStyles.subtitle.copyWith(color: _bodyText),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        counterText: '',
        labelStyle: AppTextStyles.captionBold.copyWith(
          color: const Color(0xFF6F6258),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: _accentRed, width: 2),
        ),
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _DialogActions({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            '取消',
            style: AppTextStyles.bodyEmphasisBold.copyWith(color: _bodyText),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentRed,
            foregroundColor: _paperColor,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
              side: const BorderSide(color: Colors.black, width: 1),
            ),
          ),
          onPressed: onSave,
          child: Text(
            '儲存',
            style: AppTextStyles.bodyEmphasisBold.copyWith(color: _paperColor),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String accountName;
  final String shopName;
  final String shopDescription;
  final String shopAddress;
  final String category;
  final String subCategory;
  final String imageUrl;
  final List<OperatingHour> hours;
  final bool isLoading;
  final VoidCallback onEditAccount;
  final VoidCallback onEditShop;
  final VoidCallback onLogout;

  const _InfoCard({
    required this.accountName,
    required this.shopName,
    required this.shopDescription,
    required this.shopAddress,
    required this.category,
    required this.subCategory,
    required this.imageUrl,
    required this.hours,
    required this.isLoading,
    required this.onEditAccount,
    required this.onEditShop,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final String categoryText = [
      _categoryLabel(category),
      subCategory,
    ].where((e) => e.isNotEmpty).join('・');

    final List<String> hourLines = _hoursLines(hours);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
          decoration: BoxDecoration(
            color: _paperColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _paperBorder, width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: _darkText,
                blurRadius: 0,
                spreadRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SectionTitle(
                  icon: 'img/shop_icon.png',
                  title: '帳號與店家資訊',
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  text: '使用者名稱：${accountName.isEmpty ? '尚未設定' : accountName}',
                  showEdit: true,
                  onEdit: onEditAccount,
                ),
                const SizedBox(height: 12),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else ...[
                  if (imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        width: double.infinity,
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _InfoRow(
                    text: '店家名稱：${shopName.isEmpty ? '尚未設定' : shopName}',
                    showEdit: true,
                    onEdit: onEditShop,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    text:
                        '店家介紹：\n${shopDescription.isEmpty ? '尚未設定' : shopDescription}',
                    showEdit: false,
                    onEdit: onEditShop,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    text:
                        '店家地址：\n${shopAddress.isEmpty ? '尚未設定' : shopAddress}',
                    showEdit: false,
                    onEdit: onEditShop,
                  ),
                  if (categoryText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      text: '店家類別：$categoryText',
                      showEdit: false,
                      onEdit: onEditShop,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '營業時間：${hourLines.isEmpty ? '尚未設定' : ''}',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: _bodyText,
                      height: 1.35,
                    ),
                  ),
                  for (final String line in hourLines)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 8),
                      child: Text(
                        line,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _bodyText,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 25),
                Center(
                  child: _LogoutButton(text: '登出', onTap: onLogout),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 7,
          left: 0,
          right: 0,
          child: Center(child: _Pin()),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(icon, width: 27, height: 27, fit: BoxFit.contain),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.pageTitle.copyWith(
              color: Colors.black,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  final bool showEdit;
  final VoidCallback onEdit;

  const _InfoRow({
    required this.text,
    required this.showEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final int separatorIndex = text.indexOf('：');

    final String label = separatorIndex >= 0
        ? text.substring(0, separatorIndex + 1)
        : '';

    final String value = separatorIndex >= 0
        ? text.substring(separatorIndex + 1)
        : text;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: _bodyText,
                    height: 1.35,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: _bodyText,
                    height: 1.35,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showEdit) ...[const SizedBox(width: 8), _EditButton(onTap: onEdit)],
      ],
    );
  }
}

class _EditButton extends StatefulWidget {
  final VoidCallback onTap;

  const _EditButton({required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.90 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Image.asset(
          'img/edit.png',
          width: 31,
          height: 31,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 31,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 21,
            height: 21,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.35, -0.4),
                radius: 0.9,
                colors: [
                  Color(0xFFE52F0E),
                  Color(0xFFB91F0C),
                  AppColors.deepRed,
                ],
                stops: [0.0, 0.42, 1.0],
              ),
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.dangerDark, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x80000000),
                  offset: Offset(2, 3),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          Positioned(
            left: 5,
            top: 4,
            child: Container(
              width: 5,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _LogoutButton({required this.text, required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool pressing = false;

  @override
  Widget build(BuildContext context) {
    final double scale = pressing ? 0.96 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressing = true),
      onTapUp: (_) => setState(() => pressing = false),
      onTapCancel: () => setState(() => pressing = false),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutBack,
        child: Container(
          width: 275,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
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
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.paper,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSnackBar extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _TopSnackBar({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF40342D),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 後端的 store_address 可能已含縣市與區，已含就不重複加
String _joinAddress(String city, String town, String address) {
  final String c = city.trim();
  final String t = town.trim();
  final String a = address.trim();

  String norm(String s) => s.replaceAll('台', '臺');

  if (c.isNotEmpty && norm(a).startsWith(norm(c))) return a;

  return '$c$t$a';
}

String _categoryLabel(String category) {
  switch (category) {
    case 'Attraction':
      return '景點';
    case 'Restaurant':
      return '餐廳';
    case 'Hotel':
      return '住宿';
    case 'Event':
      return '活動';
    default:
      return category;
  }
}

List<OperatingHour> _sortedHours(List<OperatingHour> hours) {
  return List<OperatingHour>.of(hours)..sort((a, b) {
    final int byDay = OperatingHour.days
        .indexOf(a.dayOfWeek)
        .compareTo(OperatingHour.days.indexOf(b.dayOfWeek));

    return byDay != 0 ? byDay : a.openTime.compareTo(b.openTime);
  });
}

/// 比對兩份營業時間是否相同（不看順序）
String _hoursKey(List<OperatingHour> hours) {
  final List<String> keys =
      hours.map((h) => '${h.dayOfWeek}|${h.openTime}|${h.closeTime}').toList()
        ..sort();

  return keys.join(';');
}

/// 每天一行；同一天多個時段用頓號串起，沒有資料的日子顯示公休，
/// 結束時間不晚於開始時間代表次日
List<String> _hoursLines(List<OperatingHour> hours) {
  if (hours.isEmpty) return const [];

  return [
    for (final String day in OperatingHour.days)
      () {
        final List<OperatingHour> slots =
            hours.where((h) => h.dayOfWeek == day).toList()
              ..sort((a, b) => a.openTime.compareTo(b.openTime));

        final String text = slots.isEmpty
            ? '公休'
            : slots
                  .map(
                    (s) => s.closeTime.compareTo(s.openTime) <= 0
                        ? '${s.openTime}–次日${s.closeTime}'
                        : '${s.openTime}–${s.closeTime}',
                  )
                  .join('、');

        return '${OperatingHour.dayLabels[day] ?? day}　$text';
      }(),
  ];
}
