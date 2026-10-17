import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class MerchantCategory {
  final String category;
  final String name;
  final String? defaultSubCategory;
  final List<String> subCategories;

  const MerchantCategory({
    required this.category,
    required this.name,
    required this.defaultSubCategory,
    required this.subCategories,
  });

  factory MerchantCategory.fromJson(Map<String, dynamic> json) {
    return MerchantCategory(
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultSubCategory: json['default_sub_category']?.toString(),
      subCategories: (json['sub_categories'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class OperatingHour {
  final String dayOfWeek;
  final String openTime;
  final String closeTime;

  const OperatingHour({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
  });

  Map<String, dynamic> toJson() => {
    'day_of_week': dayOfWeek,
    'open_time': openTime,
    'close_time': closeTime,
  };

  static const List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const Map<String, String> dayLabels = {
    'Monday': '週一',
    'Tuesday': '週二',
    'Wednesday': '週三',
    'Thursday': '週四',
    'Friday': '週五',
    'Saturday': '週六',
    'Sunday': '週日',
  };

  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static int _minutes(String time) {
    final List<String> p = time.split(':');

    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// 格式或時段重疊有問題時回傳提示文字，沒問題回傳 null。
  /// 結束時間不晚於開始時間代表跨夜（隔天結束），00:00 結束代表半夜 12 點
  static String? validate(List<OperatingHour> hours) {
    final Map<String, List<List<int>>> byDay = {};

    for (final OperatingHour h in hours) {
      final String label = dayLabels[h.dayOfWeek] ?? h.dayOfWeek;

      if (!days.contains(h.dayOfWeek)) {
        return '星期格式不正確：${h.dayOfWeek}';
      }

      if (!_timePattern.hasMatch(h.openTime) ||
          !_timePattern.hasMatch(h.closeTime)) {
        return '$label 的時間格式需為 HH:mm（例如 09:30）';
      }

      final int open = _minutes(h.openTime);
      int close = _minutes(h.closeTime);

      if (close == open) {
        return '$label 的開始與結束時間不可相同';
      }

      if (close < open) close += 1440;

      for (final List<int> other in byDay[h.dayOfWeek] ?? const []) {
        if (open < other[1] && other[0] < close) {
          return '$label 的營業時段重疊，請調整';
        }
      }

      byDay.putIfAbsent(h.dayOfWeek, () => []).add([open, close]);
    }

    return null;
  }
}

class MerchantRegisterApi {
  MerchantRegisterApi._();

  static String get _baseUrl {
    final String value = (dotenv.env['API_BASE_URL'] ?? '').trim();

    if (value.isEmpty) return 'https://backend.angelalala.com';

    return value.replaceFirst(RegExp(r'/$'), '');
  }

  static Future<List<MerchantCategory>> fetchCategories() async {
    final http.Response response = await http.get(
      Uri.parse('$_baseUrl/api/merchant/register/categories'),
      headers: const {'Accept': 'application/json, text/plain, */*'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('取得分類失敗：HTTP ${response.statusCode}');
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data is! Map || data['isSuccess'] != true || data['Result'] is! List) {
      throw Exception(data is Map ? '${data['message']}' : '取得分類失敗');
    }

    return (data['Result'] as List)
        .whereType<Map>()
        .map((e) => MerchantCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 上傳店家照片，回傳可用的完整圖片網址
  static Future<String> uploadImage(XFile file) async {
    final String ext = file.name.split('.').last.toLowerCase();
    final String subtype = ext == 'jpg' ? 'jpeg' : ext;

    final http.MultipartRequest request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/Upload'))
          ..headers['accept'] = 'text/plain'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              await file.readAsBytes(),
              filename: file.name,
              contentType: MediaType('image', subtype),
            ),
          );

    final http.Response response = await http.Response.fromStream(
      await request.send(),
    );

    dynamic data;

    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }

    final String url = data is Map ? data['Result']?.toString() ?? '' : '';

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data is! Map ||
        data['isSuccess'] != true ||
        !url.startsWith('http')) {
      final String message = data is Map
          ? data['message']?.toString() ?? ''
          : '';

      throw Exception(message.isEmpty ? '圖片上傳失敗' : '請確認檔案格式');
    }

    return url;
  }
}
