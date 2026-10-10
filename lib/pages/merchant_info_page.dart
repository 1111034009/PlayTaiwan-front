import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/app_session.dart';

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

  void _applyMerchantProfile(
    Map<String, dynamic> data, {
    bool updateSession = true,
  }) {
    if (updateSession) {
      AppSession.updateMerchantProfile(data);
    }

    final profile = AppSession.merchantProfile ?? data;

    if (!mounted) {
      shopName = profile['store_name']?.toString() ?? shopName;
      shopDescription = profile['store_dec']?.toString() ?? shopDescription;
      shopAddress = profile['store_address']?.toString() ?? shopAddress;
      shopCity = profile['store_city']?.toString() ?? shopCity;
      shopTown = profile['store_town']?.toString() ?? shopTown;

      final dynamic lat = profile['lat'];
      final dynamic lng = profile['lng'];

      shopLat = lat is num ? lat.toDouble() : double.tryParse('$lat');
      shopLng = lng is num ? lng.toDouble() : double.tryParse('$lng');

      return;
    }

    setState(() {
      shopName = profile['store_name']?.toString() ?? '';
      shopDescription = profile['store_dec']?.toString() ?? '';
      shopAddress = profile['store_address']?.toString() ?? '';
      shopCity = profile['store_city']?.toString() ?? '';
      shopTown = profile['store_town']?.toString() ?? '';

      final dynamic lat = profile['lat'];
      final dynamic lng = profile['lng'];

      shopLat = lat is num ? lat.toDouble() : double.tryParse('$lat');
      shopLng = lng is num ? lng.toDouble() : double.tryParse('$lng');
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

      final decoded = jsonDecode(response.body);

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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (mounted) _showSnackBar('更新店家資訊失敗');

        return false;
      }

      Map<String, dynamic> data = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      if (data['isSuccess'] == false) {
        if (mounted) {
          _showSnackBar(data['message']?.toString() ?? '更新店家資訊失敗');
        }

        return false;
      }

      return true;
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
          // 固定在畫面底部，避開系統導覽列
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

    final String newFullAddress =
        '${result.city}${result.town}${result.address}';

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

    if (fields.isEmpty) return;

    final bool success = await _updateMerchantProfile(fields);

    if (!success || !mounted) return;

    final updatedProfile = <String, dynamic>{
      'store_name': result.name.trim(),
      'store_dec': result.description.trim(),
      'store_address': addressChanged ? result.address : shopAddress,
      'store_city': addressChanged ? result.city : shopCity,
      'store_town': addressChanged ? result.town : shopTown,
      'lat': addressChanged ? result.lat : shopLat,
      'lng': addressChanged ? result.lng : shopLng,
    };

    AppSession.updateMerchantProfile(updatedProfile);

    setState(() {
      shopName = updatedProfile['store_name'] as String;
      shopDescription = updatedProfile['store_dec'] as String;
      shopAddress = updatedProfile['store_address'] as String;
      shopCity = updatedProfile['store_city'] as String;
      shopTown = updatedProfile['store_town'] as String;
      shopLat = updatedProfile['lat'] as double?;
      shopLng = updatedProfile['lng'] as double?;
    });

    _showSnackBar('店家資訊更新成功');
  }

  String get _fullAddress {
    final String city = shopCity.trim();
    final String town = shopTown.trim();
    final String address = shopAddress.trim();

    return '$city$town$address';
  }

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

  const _MerchantEditResult({
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.town,
    required this.lat,
    required this.lng,
    required this.addressConfirmed,
  });
}

class _MerchantEditDialog extends StatefulWidget {
  final String initialName;
  final String initialDescription;
  final String initialAddress;
  final String initialCity;
  final String initialTown;
  final double? initialLat;
  final double? initialLng;

  const _MerchantEditDialog({
    required this.initialName,
    required this.initialDescription,
    required this.initialAddress,
    required this.initialCity,
    required this.initialTown,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<_MerchantEditDialog> createState() => _MerchantEditDialogState();
}

class _MerchantEditDialogState extends State<_MerchantEditDialog> {
  String get _apiBaseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController addressController;

  late String city;
  late String town;

  double? lat;
  double? lng;

  bool addressConfirmed = true;
  bool isGeocoding = false;

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

    addressController.addListener(_onAddressChanged);
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
        if (mounted) {
          _showMessage('地址轉換失敗（HTTP ${response.statusCode}），請稍後再試');
        }
        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        if (mounted) {
          _showMessage('地址轉換 API 回傳格式錯誤');
        }
        return;
      }

      if (decoded['isSuccess'] != true) {
        if (mounted) {
          _showMessage(decoded['message']?.toString() ?? '地址轉換失敗');
        }
        return;
      }

      final dynamic result = decoded['Result'];

      if (result is! Map) {
        if (mounted) {
          _showMessage('地址轉換 API 未回傳座標資料');
        }
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
        if (mounted) {
          _showMessage('API 未回傳有效的經緯度');
        }
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
      });

      _showMessage(
        '地址確認成功\n'
        '緯度：${resultLat.toStringAsFixed(6)}，'
        '經度：${resultLng.toStringAsFixed(6)}',
      );
    } on TimeoutException {
      if (mounted) {
        _showMessage('地址查詢逾時，請稍後再試');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('地址轉換失敗，請確認網路連線或稍後再試');
      }
    } finally {
      if (mounted) {
        setState(() {
          isGeocoding = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final String name = nameController.text.trim();
    final String address = addressController.text.trim();

    if (name.isEmpty) {
      _showMessage('店家名稱不可為空');
      return;
    }

    final bool addressChanged = address != widget.initialAddress;

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

      Navigator.pop(
        context,
        _MerchantEditResult(
          name: name,
          description: descriptionController.text.trim(),
          address: parsed['address']!,
          city: parsed['city']!,
          town: parsed['town']!,
          lat: lat,
          lng: lng,
          addressConfirmed: true,
        ),
      );

      return;
    }

    Navigator.pop(
      context,
      _MerchantEditResult(
        name: name,
        description: descriptionController.text.trim(),
        address: widget.initialAddress,
        city: widget.initialCity,
        town: widget.initialTown,
        lat: widget.initialLat,
        lng: widget.initialLng,
        addressConfirmed: true,
      ),
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
  final bool isLoading;
  final VoidCallback onEditAccount;
  final VoidCallback onEditShop;
  final VoidCallback onLogout;

  const _InfoCard({
    required this.accountName,
    required this.shopName,
    required this.shopDescription,
    required this.shopAddress,
    required this.isLoading,
    required this.onEditAccount,
    required this.onEditShop,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
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
                  _InfoRow(
                    text: '店家名稱：${shopName.isEmpty ? '尚未設定' : shopName}',
                    showEdit: true,
                    onEdit: onEditShop,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    text:
                        '店家介紹：${shopDescription.isEmpty ? '尚未設定' : shopDescription}',
                    showEdit: false,
                    onEdit: onEditShop,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    text: '店家地址：${shopAddress.isEmpty ? '尚未設定' : shopAddress}',
                    showEdit: false,
                    onEdit: onEditShop,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.sectionTitle.copyWith(
              color: _bodyText,
              height: 1.35,
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
                color: Colors.white.withOpacity(0.5),
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
