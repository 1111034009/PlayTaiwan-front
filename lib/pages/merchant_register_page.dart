import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../block/merchant_register_popup.dart';

InputDecoration storyRegisterInputDecoration({
  required String hintText,
  Widget? suffixIcon,
}) {
  const border = UnderlineInputBorder(
    borderSide: BorderSide(color: AppColors.inputLine, width: 1),
  );

  return InputDecoration(
    hintText: hintText,
    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.inputHint),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 0),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    errorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}

class StoryRegisterPage extends StatefulWidget {
  const StoryRegisterPage({super.key});

  @override
  State<StoryRegisterPage> createState() => _StoryRegisterPageState();
}

class _StoryRegisterPageState extends State<StoryRegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _authNameController = TextEditingController();
  final TextEditingController _authEmailController = TextEditingController();
  final TextEditingController _authPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeDescriptionController =
      TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _placeKeywordController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isGeocoding = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _addressConfirmed = false;
  bool _addressApproximate = false;
  String _confirmedAddress = '';
  double? _confirmedLat;
  double? _confirmedLng;

  String? _selectedPlaceUid;
  String? _selectedPlaceName;
  String? _selectedPlaceAddress;

  Map<String, dynamic>? _newPlace;

  String get _apiBaseUrl {
    final String value = (dotenv.env['API_BASE_URL'] ?? '').trim();

    if (value.isEmpty) return 'https://backend.angelalala.com';

    return value.replaceFirst(RegExp(r'/$'), '');
  }

  @override
  void initState() {
    super.initState();

    _storeAddressController.addListener(_onAddressChanged);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _authNameController.dispose();
    _authEmailController.dispose();
    _authPasswordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storeAddressController.dispose();
    _placeKeywordController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    if (_addressConfirmed &&
        _storeAddressController.text.trim() != _confirmedAddress) {
      setState(() {
        _addressConfirmed = false;
        _addressApproximate = false;
        _confirmedLat = null;
        _confirmedLng = null;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = map[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  List<Map<String, dynamic>> _extractPlaceList(dynamic decoded) {
    if (decoded is! Map) return [];

    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);

    if (map['isSuccess'] != true) return [];

    final dynamic data = map['Result'];

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _searchPlaces() async {
    FocusScope.of(context).unfocus();

    if (_isSearching) return;

    final String keyword = _placeKeywordController.text.trim().isNotEmpty
        ? _placeKeywordController.text.trim()
        : _storeNameController.text.trim();

    if (keyword.isEmpty) {
      _showMessage('請輸入地點名稱或店家名稱再搜尋。');
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final Uri uri = Uri.parse(
        '$_apiBaseUrl/api/merchant/register/search-place',
      ).replace(queryParameters: {'keyword': keyword});

      final http.Response response = await http.get(
        uri,
        headers: const {'Accept': 'application/json, text/plain, */*'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}：${response.body}');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map && decoded['isSuccess'] != true) {
        throw Exception(decoded['message']?.toString() ?? '搜尋失敗');
      }

      final List<Map<String, dynamic>> results = _extractPlaceList(decoded);

      if (!mounted) return;

      final Map<String, dynamic>? selected = await StorySearchPopup.show(
        context,
        results: results,
      );

      if (!mounted || selected == null) return;

      _selectExistingPlace(selected);
    } catch (e) {
      _showMessage('搜尋地點失敗：${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  String _getPlaceUid(Map<String, dynamic> place) {
    return _firstString(place, [
      'place_uid',
      'placeUid',
      'placeUID',
      'uid',
      'place_id',
      'placeId',
      'id',
    ]);
  }

  String _getPlaceName(Map<String, dynamic> place) {
    return _firstString(place, [
      'name',
      'place_name',
      'placeName',
      'title',
      'store_name',
    ]);
  }

  String _getPlaceAddress(Map<String, dynamic> place) {
    return _firstString(place, [
      'address',
      'place_address',
      'placeAddress',
      'formatted_address',
      'store_address',
    ]);
  }

  void _selectExistingPlace(Map<String, dynamic> place) {
    final String uid = _getPlaceUid(place);

    if (uid.isEmpty) {
      _showMessage('搜尋結果缺少 uid，請確認後端回傳欄位。');
      return;
    }

    final String name = _getPlaceName(place);
    final String address = _getPlaceAddress(place);

    if (name.isNotEmpty) {
      _storeNameController.text = name;
    }

    if (address.isNotEmpty) {
      _storeAddressController.text = address;
    }

    setState(() {
      _selectedPlaceUid = uid;
      _selectedPlaceName = name.isEmpty ? '已選擇地點' : name;
      _selectedPlaceAddress = address;
      _newPlace = null;
      _addressConfirmed = false;
      _addressApproximate = false;
      _confirmedLat = null;
      _confirmedLng = null;
    });

    _showMessage('已帶入地點資訊，請確認店家地址。');
  }

  Future<void> _startCreatingNewPlace() async {
    FocusScope.of(context).unfocus();

    final Map<String, dynamic> initial = _newPlace != null
        ? Map<String, dynamic>.from(_newPlace!)
        : <String, dynamic>{
            'name': _storeNameController.text.trim(),
            'description': _storeDescriptionController.text.trim(),
            'address': _storeAddressController.text.trim(),
            'category': 'Restaurant',
            if (_addressConfirmed &&
                _confirmedAddress == _storeAddressController.text.trim()) ...{
              'lat': _confirmedLat,
              'lng': _confirmedLng,
            },
          };

    final Map<String, dynamic>? result = await StoryNewPlacePopup.show(
      context,
      initial: initial,
    );

    if (!mounted || result == null) return;

    final String fullAddress = result['full_address'].toString();

    _storeNameController.text = result['name'].toString();
    _storeDescriptionController.text = result['description'].toString();
    _storeAddressController.text = fullAddress;

    setState(() {
      _newPlace = result;
      _selectedPlaceUid = null;
      _selectedPlaceName = null;
      _selectedPlaceAddress = null;
      _addressConfirmed = true;
      _addressApproximate = result['approximate'] == true;
      _confirmedAddress = fullAddress;
      _confirmedLat = (result['lat'] as num).toDouble();
      _confirmedLng = (result['lng'] as num).toDouble();
    });

    _showMessage('新地點資訊已帶入店家資訊。');
  }

  Future<void> _confirmAddress() async {
    FocusScope.of(context).unfocus();

    if (_isGeocoding) return;

    final String input = _storeAddressController.text.trim();

    if (input.isEmpty) {
      _showMessage('請先輸入店家地址。');
      return;
    }

    final ParsedTaiwanAddress? parsed = parseTaiwanAddress(input);

    if (parsed == null) {
      _showMessage('地址格式不完整，請輸入縣市、行政區及門牌號碼。例如：臺中市西區公益路100號');
      return;
    }

    setState(() {
      _isGeocoding = true;
    });

    try {
      final GeocodeResult result = await geocodeTaiwanAddress(parsed);

      if (!mounted) return;

      if (_storeAddressController.text.trim() != input) return;

      setState(() {
        _addressConfirmed = true;
        _addressApproximate = result.approximate;
        _confirmedAddress = input;
        _confirmedLat = result.lat;
        _confirmedLng = result.lng;
      });

      _showMessage(result.approximate ? '已找到道路位置，但無法精確定位門牌。' : '地址確認成功！');
    } catch (e) {
      _showMessage('地址確認失敗：${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  String? _validateUsername(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入帳號名稱';
    if (text.length < 2) return '帳號名稱至少需要 2 個字元';
    if (text.length > 40) return '帳號名稱不可超過 40 個字元';

    return null;
  }

  String? _validateEmail(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入電子郵件';

    final RegExp emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailPattern.hasMatch(text)) {
      return '請輸入有效的電子郵件格式';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) return '請輸入密碼';

    if (password.length < 8 || password.length > 40) {
      return '密碼長度需介於 8 至 40 個字元';
    }

    if (RegExp(r'\s').hasMatch(password)) {
      return '密碼不可包含空白';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return '密碼需包含至少一個英文字母及一個數字';
    }

    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(password)) {
      return '密碼不可包含中文';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) return '請再次輸入密碼';

    if (value != _authPasswordController.text) {
      return '兩次輸入的密碼不一致';
    }

    return null;
  }

  String? _validateStoreName(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入店家名稱';
    if (text.length > 50) return '店家名稱不可超過 50 個字元';

    return null;
  }

  String? _validateStoreDescription(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入店家介紹';
    if (text.length < 5) return '店家介紹至少需要 5 個字';
    if (text.length > 300) return '店家介紹不可超過 300 個字';

    return null;
  }

  String? _validateAddress(String? value) {
    final String input = value?.trim() ?? '';

    if (input.isEmpty) return '請輸入店家地址';

    return null;
  }

  bool _validateBeforeSubmit() {
    final bool valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      _showMessage('請檢查表單中的欄位。');
      return false;
    }

    if (_newPlace == null &&
        (_selectedPlaceUid == null || _selectedPlaceUid!.isEmpty)) {
      _showMessage('請先搜尋並選擇既有地點，或建立新地點。');
      return false;
    }

    return true;
  }

  Map<String, dynamic> _buildPayload(String address) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'auth_name': _authNameController.text.trim(),
      'auth_email': _authEmailController.text.trim().toLowerCase(),
      'auth_pswd': _authPasswordController.text,
      'store_name': _storeNameController.text.trim(),
      'store_dec': _storeDescriptionController.text.trim(),
      'store_address': address,
    };

    final Map<String, dynamic>? place = _newPlace;

    if (place != null) {
      final Map<String, dynamic> newPlace = <String, dynamic>{
        'name': place['name'],
        'address': place['address'],
        'description': place['description'],
      };

      for (final String key in ['phone', 'website', 'opening_hours']) {
        final String value = place[key]?.toString().trim() ?? '';

        if (value.isNotEmpty) newPlace[key] = value;
      }

      newPlace['lat'] = place['lat'];
      newPlace['lng'] = place['lng'];
      newPlace['category'] = place['category'];

      payload['new_place'] = newPlace;
    } else {
      payload['place_uid'] = _selectedPlaceUid;
    }

    return payload;
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();

    if (_isLoading || !_validateBeforeSubmit()) return;

    final String address = _storeAddressController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> payload = _buildPayload(address);
      final Uri uri = Uri.parse('$_apiBaseUrl/api/Merchant/Register');

      final http.Response response = await http.post(
        uri,
        headers: const {
          'Accept': 'text/plain, application/json, */*',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final String responseText = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        _showMessage('店家註冊成功！');

        await Future<void>.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      } else {
        final String message = responseText.trim().isEmpty
            ? '店家註冊失敗，稍後嘗試'
            : '店家註冊失敗，稍後嘗試';

        _showMessage(message);
      }
    } catch (e) {
      _showMessage('註冊時發生錯誤：${_errorText(e)}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    TextAlign textAlign = TextAlign.center,
    TextAlignVertical? textAlignVertical,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          TextFormField(
            controller: controller,
            validator: validator,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: !obscureText,
            keyboardType: obscureText
                ? TextInputType.visiblePassword
                : keyboardType,
            inputFormatters: inputFormatters,
            maxLines: obscureText ? 1 : maxLines,
            textAlign: textAlign,
            textAlignVertical: textAlignVertical,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            cursorColor: AppColors.primary,
            decoration: storyRegisterInputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return _buildTextField(
      label: label,
      controller: controller,
      hint: hint,
      validator: validator,
      obscureText: obscureText,
      inputFormatters: [
        LengthLimitingTextInputFormatter(40),
        FilteringTextInputFormatter.deny(RegExp(r'[\s\u4E00-\u9FFF]')),
      ],
      suffixIcon: IconButton(
        tooltip: obscureText ? '顯示密碼' : '隱藏密碼',
        padding: EdgeInsets.zero,
        splashRadius: 20,
        onPressed: onToggle,
        icon: Icon(
          obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
    );
  }

  Widget _buildLocationMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _placeKeywordController,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  cursorColor: AppColors.primary,
                  decoration:
                      storyRegisterInputDecoration(
                        hintText: '輸入地點名稱或店家名稱',
                      ).copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchPlaces(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSearching ? null : _searchPlaces,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: AppColors.primaryDark,
                      width: 1.2,
                    ),
                  ),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 23),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedPlaceUid != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已選擇既有地點',
                        style: AppTextStyles.bodySmallBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedPlaceName ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if ((_selectedPlaceAddress ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _selectedPlaceAddress!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary.withOpacity(0.70),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedPlaceUid = null;
                        _selectedPlaceName = null;
                        _selectedPlaceAddress = null;
                      });
                    },
                    child: Text(
                      '重新選擇地點',
                      style: AppTextStyles.bodySmallBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_selectedPlaceUid == null && _newPlace == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startCreatingNewPlace,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(
                '建立新的地點',
                style: AppTextStyles.bodySmallBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.65)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        if (_newPlace != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已準備建立新地點：${_newPlace!['name']}',
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _startCreatingNewPlace,
                  child: Text(
                    '編輯',
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _newPlace = null;
                    });
                  },
                  child: Text(
                    '移除',
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAddressConfirm() {
    final bool canConfirm = !_isGeocoding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirmAddress : null,
            style: _primaryButtonStyle(),
            child: _isGeocoding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _addressConfirmed ? '重新確認地址' : '確認地址',
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (_addressConfirmed && _confirmedLat != null && _confirmedLng != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✓ 地址確認成功',
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            '輸入地址後請按「確認地址」，確認後才能註冊。',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.deepOrange),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        width: 240,
        height: 45,
        child: _StoryRegisterButton(
          isLoading: _isLoading,
          enabled: true,
          onPressed: _submitRegistration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 23, top: 5),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (Route<dynamic> route) => false,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 5,
                            ),
                            child: Text(
                              '<< 返回',
                              style: AppTextStyles.bodySmallBold.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 24),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(29, 30, 29, 32),
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('img/story_papper.png'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                '建立商家帳號',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '建立你的專屬商家身份',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmallBold.copyWith(
                                  color: const Color(0xFF66615C),
                                ),
                              ),
                              _sectionTitle('帳號資訊'),
                              _buildTextField(
                                label: '帳號名稱',
                                controller: _authNameController,
                                hint: '請輸入帳號名稱',
                                validator: _validateUsername,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(40),
                                ],
                              ),
                              _buildTextField(
                                label: '電子信箱',
                                controller: _authEmailController,
                                hint: '請輸入 Email',
                                validator: _validateEmail,
                                keyboardType: TextInputType.emailAddress,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(100),
                                  FilteringTextInputFormatter.deny(
                                    RegExp(r'\s'),
                                  ),
                                ],
                              ),
                              _buildPasswordField(
                                label: '通行密碼',
                                controller: _authPasswordController,
                                hint: '至少 8 個字元，包含英文字母與數字',
                                validator: _validatePassword,
                                obscureText: _obscurePassword,
                                onToggle: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              _buildPasswordField(
                                label: '確認密碼',
                                controller: _confirmPasswordController,
                                hint: '再次輸入密碼',
                                validator: _validateConfirmPassword,
                                obscureText: _obscureConfirmPassword,
                                onToggle: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              _sectionTitle('店家資訊'),
                              _buildLocationMode(),
                              const SizedBox(height: 15),
                              _buildTextField(
                                label: '店家名稱',
                                controller: _storeNameController,
                                hint: '請輸入店家名稱',
                                validator: _validateStoreName,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(50),
                                ],
                              ),
                              _buildTextField(
                                label: '店家介紹',
                                controller: _storeDescriptionController,
                                hint: '請簡單介紹你的店家',
                                maxLines: 3,
                                validator: _validateStoreDescription,
                                keyboardType: TextInputType.multiline,
                                textAlign: TextAlign.start,
                                textAlignVertical: TextAlignVertical.top,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(300),
                                ],
                              ),
                              _buildTextField(
                                label: '店家地址',
                                controller: _storeAddressController,
                                hint: '例如：臺中市西區公益路100號',
                                validator: _validateAddress,
                                keyboardType: TextInputType.streetAddress,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(100),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildSubmitButton(),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StoryRegisterButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;

  const _StoryRegisterButton({
    required this.onPressed,
    required this.isLoading,
    required this.enabled,
  });

  @override
  State<_StoryRegisterButton> createState() => _StoryRegisterButtonState();
}

class _StoryRegisterButtonState extends State<_StoryRegisterButton> {
  bool hovering = false;
  bool pressing = false;

  bool get active => widget.enabled && !widget.isLoading;

  double get scale {
    if (!widget.enabled) return 1.0;
    if (pressing) return 0.96;
    if (hovering) return 1.08;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: GestureDetector(
        onTap: active ? widget.onPressed : null,
        onTapDown: (_) {
          if (!active) return;

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
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 160),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: Container(
              width: 240,
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.primaryDark, width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryLight, AppColors.primary],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x70000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '註冊',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
