import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../api/merchant_register_api.dart';

class ParsedTaiwanAddress {
  final String city;
  final String town;
  final String address;

  const ParsedTaiwanAddress({
    required this.city,
    required this.town,
    required this.address,
  });
}

String _normalizeDigits(String input) {
  return input.replaceAllMapped(RegExp(r'[０-９]'), (Match m) {
    return String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFF10 + 0x30);
  });
}

ParsedTaiwanAddress? parseTaiwanAddress(String input) {
  String address = _normalizeDigits(input).trim().replaceAll('　', ' ');
  address = address.replaceFirst(RegExp(r'^(中華民國|台灣|臺灣)\s*'), '');

  const List<String> cities = [
    '臺北市',
    '台北市',
    '新北市',
    '桃園市',
    '臺中市',
    '台中市',
    '臺南市',
    '台南市',
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
    '台東縣',
    '澎湖縣',
    '金門縣',
    '連江縣',
  ];

  String? city;

  for (final String candidate in cities) {
    if (address.startsWith(candidate)) {
      city = candidate;
      address = address.substring(candidate.length).trim();
      break;
    }
  }

  if (city == null) return null;

  final RegExpMatch? townMatch = RegExp(
    r'^(.{1,4}?(?:區|鄉|鎮|市))',
  ).firstMatch(address);

  if (townMatch == null) return null;

  final String town = townMatch.group(1)!.trim();

  final String streetAddress = address
      .substring(townMatch.end)
      .trim()
      .replaceFirst(RegExp(r'^[,，、\s]+'), '');

  if (streetAddress.isEmpty || !RegExp(r'\d').hasMatch(streetAddress)) {
    return null;
  }

  return ParsedTaiwanAddress(city: city, town: town, address: streetAddress);
}

class GeocodeResult {
  final double lat;
  final double lng;
  final bool approximate;

  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.approximate,
  });
}

Future<GeocodeResult> geocodeTaiwanAddress(ParsedTaiwanAddress parsed) async {
  final Uri uri = Uri.https(
    'backend.angelalala.com',
    '/api/merchant/register/address-to-location',
    {
      'store_city': parsed.city,
      'store_town': parsed.town,
      'store_address': parsed.address,
    },
  );

  final http.Response response = await http.get(
    uri,
    headers: const {'Accept': 'text/plain'},
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('地址轉換失敗：HTTP ${response.statusCode}');
  }

  final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

  if (decoded is! Map<String, dynamic>) {
    throw Exception('地址 API 回傳格式錯誤。');
  }

  if (decoded['isSuccess'] != true) {
    throw Exception(decoded['message']?.toString() ?? '地址轉換失敗。');
  }

  final dynamic result = decoded['Result'];

  if (result is! Map<String, dynamic>) {
    throw Exception('地址 API 未回傳有效的經緯度資料。');
  }

  final double? lat = double.tryParse(result['lat']?.toString() ?? '');

  final double? lng = double.tryParse(result['lng']?.toString() ?? '');

  if (lat == null ||
      lng == null ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180) {
    throw Exception('地址 API 回傳的經緯度無效。');
  }

  return GeocodeResult(lat: lat, lng: lng, approximate: false);
}

InputDecoration _inputDecoration({required String hintText}) {
  const border = UnderlineInputBorder(
    borderSide: BorderSide(color: AppColors.inputLine, width: 1),
  );

  return InputDecoration(
    hintText: hintText,
    hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.inputHint),
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

ButtonStyle _primaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
    elevation: 2,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
      side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
    ),
  );
}

class StorySearchPopup extends StatelessWidget {
  final List<Map<String, dynamic>> results;

  const StorySearchPopup({super.key, required this.results});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> results,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => StorySearchPopup(results: results),
    );
  }

  String _value(Map<String, dynamic> item, String key) {
    return item[key]?.toString().trim() ?? '';
  }

  String _typeName(String type) {
    switch (type) {
      case 'Attraction':
        return '景點';
      case 'Restaurant':
        return '餐廳';
      case 'Hotel':
        return '旅宿';
      case 'Event':
        return '活動';
      default:
        return type.isEmpty ? '其他地點' : type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Attraction':
        return Icons.photo_camera_outlined;
      case 'Restaurant':
        return Icons.restaurant_outlined;
      case 'Hotel':
        return Icons.hotel_outlined;
      case 'Event':
        return Icons.event_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: GestureDetector(
        onTap: () {},
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 460, maxHeight: height * 0.78),
          child: Container(
            width: width,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('img/long_papper.png'),
                fit: BoxFit.fill,
                alignment: Alignment.center,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(35, 40, 35, 35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.primary,
                        size: 27,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '尋找地點',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      results.isEmpty
                          ? '尚未找到符合條件的地點'
                          : '找到 ${results.length} 個地點，選擇一個帶入店家資訊',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 30,
                                horizontal: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.travel_explore_rounded,
                                    size: 48,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    '似乎沒找到相關資訊',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '可以換個關鍵字搜尋，或建立新地點。',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                            itemBuilder: (context, index) {
                              final Map<String, dynamic> place = results[index];
                              final String name = _value(place, 'name');
                              final String address = _value(place, 'address');
                              final String type = _value(place, 'type');

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    Navigator.of(context).pop(place);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                      horizontal: 5,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            _typeIcon(type),
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isEmpty ? '未命名地點' : name,
                                                style: AppTextStyles
                                                    .bodySmallBold
                                                    .copyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              ),
                                              if (address.isNotEmpty) ...[
                                                const SizedBox(height: 5),
                                                Text(
                                                  address,
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .textPrimary
                                                            .withValues(
                                                              alpha: 0.72,
                                                            ),
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(height: 7),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _typeName(type),
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.only(top: 10),
                                          child: Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoryNewPlacePopup extends StatefulWidget {
  final Map<String, dynamic> initial;

  const StoryNewPlacePopup({super.key, required this.initial});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Map<String, dynamic> initial,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => StoryNewPlacePopup(initial: initial),
    );
  }

  @override
  State<StoryNewPlacePopup> createState() => _StoryNewPlacePopupState();
}

class _StoryNewPlacePopupState extends State<StoryNewPlacePopup> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;
  late final TextEditingController _addressController;

  String _category = 'Restaurant';
  String? _subCategory;
  List<MerchantCategory> _categories = [];
  String? _categoriesError;

  final List<_HourRow> _hours = [];
  String? _hoursError;

  bool _isGeocoding = false;
  bool _approximate = false;
  double? _lat;
  double? _lng;
  String _geocodedAddress = '';
  String? _error;

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

  List<MerchantCategory> get _categoryList =>
      _categories.isNotEmpty ? _categories : _fallbackCategories;

  MerchantCategory get _currentCategory => _categoryList.firstWhere(
    (MerchantCategory c) => c.category == _category,
    orElse: () => _categoryList.first,
  );

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic> i = widget.initial;

    String text(String key) => i[key]?.toString() ?? '';

    _nameController = TextEditingController(text: text('name'));
    _descriptionController = TextEditingController(text: text('description'));
    _phoneController = TextEditingController(text: text('phone'));
    _websiteController = TextEditingController(text: text('website'));
    _addressController = TextEditingController(
      text: text('full_address').isNotEmpty
          ? text('full_address')
          : text('address'),
    );

    final String category = text('category');

    if (['Attraction', 'Restaurant', 'Hotel', 'Event'].contains(category)) {
      _category = category;
    }

    final String sub = text('sub_category');

    if (sub.isNotEmpty) _subCategory = sub;

    final dynamic hours = i['operating_hours'];

    if (hours is List) {
      for (final Map h in hours.whereType<Map>()) {
        _hours.add(
          _HourRow(
            day: h['day_of_week']?.toString() ?? 'Monday',
            open: h['open_time']?.toString() ?? '09:00',
            close: h['close_time']?.toString() ?? '18:00',
          ),
        );
      }
    }

    final dynamic lat = i['lat'];
    final dynamic lng = i['lng'];

    if (lat is num && lng is num) {
      _lat = lat.toDouble();
      _lng = lng.toDouble();
      _approximate = i['approximate'] == true;
      _geocodedAddress = _addressController.text.trim();
    }

    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressChanged(String value) {
    if (_lat != null && value.trim() != _geocodedAddress) {
      setState(() {
        _lat = null;
        _lng = null;
        _approximate = false;
        _error = null;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final List<MerchantCategory> list =
          await MerchantRegisterApi.fetchCategories();

      if (!mounted) return;

      setState(() {
        _categories = list;
        _categoriesError = null;

        if (_subCategory != null &&
            !_currentCategory.subCategories.contains(_subCategory)) {
          _subCategory = null;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _categoriesError = '細分類載入失敗，將使用預設細分類';
      });
    }
  }

  Future<void> _geocode() async {
    FocusScope.of(context).unfocus();

    if (_isGeocoding) return;

    final String input = _addressController.text.trim();

    if (input.isEmpty) {
      setState(() {
        _error = '請先輸入地點地址。';
      });
      return;
    }

    final ParsedTaiwanAddress? parsed = parseTaiwanAddress(input);

    if (parsed == null) {
      setState(() {
        _error = '地址格式不完整，請輸入縣市、鄉鎮市區及完整門牌號碼。例如：臺中市西區公益路100號';
      });
      return;
    }

    setState(() {
      _isGeocoding = true;
      _error = null;
      _lat = null;
      _lng = null;
      _approximate = false;
      _geocodedAddress = '';
    });

    try {
      final GeocodeResult result = await geocodeTaiwanAddress(parsed);

      if (!mounted) return;

      if (_addressController.text.trim() != input) return;

      setState(() {
        _lat = result.lat;
        _lng = result.lng;
        _approximate = result.approximate;
        _geocodedAddress = input;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  String _normalizeWebsite(String value) {
    final String text = value.trim();

    if (text.isEmpty) return '';

    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) {
      return text;
    }

    return 'https://$text';
  }

  String? _validateName(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入地點名稱';
    if (text.length > 50) return '地點名稱不可超過 50 個字元';

    return null;
  }

  String? _validateDescription(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入地點介紹';
    if (text.length < 5) return '地點介紹至少需要 5 個字';
    if (text.length > 300) return '地點介紹不可超過 300 個字';

    return null;
  }

  String? _validatePhone(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final int digits = text.replaceAll(RegExp(r'\D'), '').length;

    if (digits < 7 || digits > 15) return '請輸入有效的電話號碼';

    return null;
  }

  String? _validateWebsite(String? value) {
    final String text = _normalizeWebsite(value ?? '');

    if (text.isEmpty) return null;

    final Uri? uri = Uri.tryParse(text);

    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      return '請輸入有效的網址';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) return '請輸入地點地址';

    if (parseTaiwanAddress(text) == null) {
      return '請輸入完整地址，包含縣市、行政區及門牌號碼';
    }

    return null;
  }

  String? _checkHours() {
    return OperatingHour.validate(
      _hours
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
    final _HourRow? last = _hours.isEmpty ? null : _hours.last;

    final int nextDay = last == null
        ? 0
        : (OperatingHour.days.indexOf(last.day) + 1) % 7;

    setState(() {
      _hours.add(
        _HourRow(
          day: OperatingHour.days[nextDay],
          open: last?.open ?? '09:00',
          close: last?.close ?? '18:00',
        ),
      );
      _hoursError = _checkHours();
    });
  }

  Future<void> _pickTime(_HourRow row, {required bool isOpen}) async {
    final List<String> parts = (isOpen ? row.open : row.close).split(':');

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
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

      _hoursError = _checkHours();
    });
  }

  void _confirm() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String? hoursError = _checkHours();

    if (hoursError != null) {
      setState(() {
        _hoursError = hoursError;
      });
      return;
    }

    final String address = _addressController.text.trim();

    if (_lat == null || _lng == null || _geocodedAddress != address) {
      setState(() {
        _error = '請先按確認地址。';
      });
      return;
    }

    final ParsedTaiwanAddress? parsed = parseTaiwanAddress(address);

    if (parsed == null) return;

    final List<OperatingHour> hours =
        _hours
            .map(
              (_HourRow r) => OperatingHour(
                dayOfWeek: r.day,
                openTime: r.open,
                closeTime: r.close,
              ),
            )
            .toList()
          ..sort((OperatingHour a, OperatingHour b) {
            final int byDay = OperatingHour.days
                .indexOf(a.dayOfWeek)
                .compareTo(OperatingHour.days.indexOf(b.dayOfWeek));

            return byDay != 0 ? byDay : a.openTime.compareTo(b.openTime);
          });

    Navigator.of(context).pop(<String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'phone': _phoneController.text.trim(),
      'website': _normalizeWebsite(_websiteController.text),
      'category': _category,
      if (_subCategory != null) 'sub_category': _subCategory,
      'operating_hours': hours.map((OperatingHour h) => h.toJson()).toList(),
      'city': parsed.city,
      'town': parsed.town,
      'address': parsed.address,
      'full_address': address,
      'approximate': _approximate,
      'lat': _lat,
      'lng': _lng,
    });
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
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
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            maxLines: maxLines,
            textAlign: textAlign,
            textAlignVertical: textAlignVertical,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            cursorColor: AppColors.primary,
            decoration: _inputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _timeButton(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmallBold.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildHourRow(int index) {
    final _HourRow row = _hours[index];
    final bool nextDay = row.close.compareTo(row.open) <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
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
                  decoration: _inputDecoration(hintText: ''),
                  dropdownColor: AppColors.merchantPaper,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
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
                      _hoursError = _checkHours();
                    });
                  },
                ),
              ),
              IconButton(
                tooltip: '刪除時段',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _hours.removeAt(index);
                    _hoursError = _checkHours();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
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
                    style: AppTextStyles.bodySmallBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
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
                  style: AppTextStyles.bodySmall.copyWith(
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '營業時間（選填）',
            style: AppTextStyles.bodySmallBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '公休日不用填；中午休息請同一天填兩段；跨夜營業的結束時間會算隔天。',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _hours.length; i++) _buildHourRow(i),
          if (_hoursError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _hoursError!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.redAccent,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addHourRow,
              icon: const Icon(Icons.add),
              label: Text(
                '新增時段',
                style: AppTextStyles.bodySmallBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.65),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('img/long_papper.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(35, 40, 35, 35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.add_location_alt_outlined,
                      color: AppColors.primary,
                      size: 27,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '建立新地點',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '填寫地點資訊，並輸入地址轉換成經緯度。',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field(
                            label: '地點名稱',
                            controller: _nameController,
                            hint: '例如：XX南洋炸雞',
                            validator: _validateName,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50),
                            ],
                          ),
                          _field(
                            label: '地點介紹',
                            controller: _descriptionController,
                            hint: '請介紹這個地點',
                            maxLines: 3,
                            validator: _validateDescription,
                            keyboardType: TextInputType.multiline,
                            textAlign: TextAlign.start,
                            textAlignVertical: TextAlignVertical.top,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(300),
                            ],
                          ),
                          _field(
                            label: '聯絡電話（選填）',
                            controller: _phoneController,
                            hint: '請輸入聯絡電話',
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(20),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\-() #]'),
                              ),
                            ],
                          ),
                          _field(
                            label: '官方網站（選填）',
                            controller: _websiteController,
                            hint: 'https://example.com',
                            keyboardType: TextInputType.url,
                            validator: _validateWebsite,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(200),
                              FilteringTextInputFormatter.deny(RegExp(r'\s')),
                            ],
                          ),
                          _buildHoursEditor(),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '地點類別',
                                  style: AppTextStyles.bodySmallBold.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                DropdownButtonFormField<String>(
                                  initialValue: _category,
                                  isExpanded: true,
                                  decoration: _inputDecoration(
                                    hintText: '選擇地點類別',
                                  ),
                                  dropdownColor: AppColors.merchantPaper,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                  items: [
                                    for (final MerchantCategory c
                                        in _categoryList)
                                      DropdownMenuItem(
                                        value: c.category,
                                        child: Text('${c.name} ${c.category}'),
                                      ),
                                  ],
                                  onChanged: (String? value) {
                                    if (value == null) return;

                                    setState(() {
                                      _category = value;
                                      _subCategory = null;
                                    });
                                  },
                                ),
                                if (_categoriesError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _categoriesError!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_currentCategory.subCategories.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '細分類（選填）',
                                    style: AppTextStyles.bodySmallBold.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('sub_$_category'),
                                    initialValue: _subCategory,
                                    isExpanded: true,
                                    menuMaxHeight: 320,
                                    decoration: _inputDecoration(
                                      hintText: '選擇細分類',
                                    ),
                                    dropdownColor: AppColors.merchantPaper,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    items: [
                                      DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          _currentCategory.defaultSubCategory ==
                                                  null
                                              ? '不選擇'
                                              : '使用預設（${_currentCategory.defaultSubCategory}）',
                                        ),
                                      ),
                                      for (final String s
                                          in _currentCategory.subCategories)
                                        DropdownMenuItem<String>(
                                          value: s,
                                          child: Text(s),
                                        ),
                                    ],
                                    onChanged: (String? value) {
                                      setState(() {
                                        _subCategory = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          _field(
                            label: '地點地址',
                            controller: _addressController,
                            hint: '例如：臺中市西區公益路100號',
                            keyboardType: TextInputType.streetAddress,
                            validator: _validateAddress,
                            onChanged: _onAddressChanged,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(100),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isGeocoding ? null : _geocode,
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
                                      '確認地址',
                                      style: AppTextStyles.bodySmallBold
                                          .copyWith(color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_lat != null && _lng != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
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
                              _error ?? '尚未確認地址。請輸入地址後按確認。',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: _error != null
                                    ? Colors.redAccent
                                    : Colors.deepOrange,
                              ),
                            ),
                          if (_lat != null && _error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _error!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    side: BorderSide(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(
                                    '取消',
                                    style: AppTextStyles.bodySmallBold.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _confirm,
                                  style: _primaryButtonStyle(),
                                  child: Text(
                                    '確認',
                                    style: AppTextStyles.bodySmallBold.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _HourRow {
  String day;
  String open;
  String close;

  _HourRow({required this.day, this.open = '09:00', this.close = '18:00'});
}
