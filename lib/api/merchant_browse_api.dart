import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';
import '../core/i18n.dart';

/// 營業時間（一天一筆）
class BrowseHour {
  final String dayOfWeek;
  final String openTime;
  final String closeTime;

  const BrowseHour({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
  });

  factory BrowseHour.fromJson(Map<String, dynamic> json) => BrowseHour(
    dayOfWeek: json['day_of_week']?.toString() ?? '',
    openTime: json['open_time']?.toString() ?? '',
    closeTime: json['close_time']?.toString() ?? '',
  );
}

/// 店家目前的優惠券
class BrowseCoupon {
  final int id;
  final String name;
  final String commodity;
  final String discountType; // amount（折抵金額）／percent（折扣）
  final num discountValue;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool isClaimed;
  final bool isUsed;

  const BrowseCoupon({
    required this.id,
    required this.name,
    required this.commodity,
    required this.discountType,
    required this.discountValue,
    required this.validFrom,
    required this.validTo,
    required this.isClaimed,
    required this.isUsed,
  });

  factory BrowseCoupon.fromJson(Map<String, dynamic> json) => BrowseCoupon(
    id: int.tryParse(json['coupon_id']?.toString() ?? '') ?? 0,
    name: json['coupon_name']?.toString().trim() ?? '',
    commodity: json['discount_commodity']?.toString().trim() ?? '',
    discountType: json['discount_type']?.toString() ?? '',
    discountValue: num.tryParse(json['discount_value']?.toString() ?? '') ?? 0,
    validFrom: DateTime.tryParse(json['valid_from']?.toString() ?? ''),
    validTo: DateTime.tryParse(json['valid_to']?.toString() ?? ''),
    isClaimed: json['is_claimed'] == true,
    isUsed: json['is_used'] == true,
  );

  /// 折扣文字：amount → 折 $20；percent 的 value 是「折掉幾 %」（10 = 九折）
  String get discountText {
    if (discountType == 'amount') {
      return '折 \$${_trim(discountValue)}';
    }

    if (discountType == 'percent') {
      // 「九折」是中文（含台語、客語）的說法；其他語言改說折掉幾 %（10% off）
      if (AppLang.contentLang != AppLang.zhTW) {
        return tr('折扣 {0}%', [_trim(discountValue)]);
      }
      final num pay = 100 - discountValue;

      return pay % 10 == 0
          ? '${(pay ~/ 10)} 折'
          : '${_trim(pay / 10)} 折';
    }

    return _trim(discountValue);
  }

  static String _trim(num value) => value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

/// 一間店
class BrowseStore {
  final int id;
  final String name;
  final String description;
  final String city;
  final String town;
  final String address;
  final String imageUrl;
  final List<BrowseHour> hours;
  final List<BrowseCoupon> coupons;

  const BrowseStore({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.town,
    required this.address,
    required this.imageUrl,
    required this.hours,
    required this.coupons,
  });

  factory BrowseStore.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) build) {
      if (raw is! List) return const [];

      return [
        for (final dynamic e in raw)
          if (e is Map) build(Map<String, dynamic>.from(e)),
      ];
    }

    return BrowseStore(
      id: int.tryParse(json['s_id']?.toString() ?? '') ?? 0,
      name: json['store_name']?.toString().trim() ?? '',
      description: json['store_dec']?.toString().trim() ?? '',
      city: json['store_city']?.toString().trim() ?? '',
      town: json['store_town']?.toString().trim() ?? '',
      address: json['full_address']?.toString().trim() ?? '',
      imageUrl: json['image_url']?.toString().trim() ?? '',
      hours: list(json['operating_hours'], BrowseHour.fromJson),
      coupons: list(json['coupons'], BrowseCoupon.fromJson),
    );
  }

  /// 今天的營業時間（找不到回 null）
  BrowseHour? get today {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final String name = names[DateTime.now().weekday - 1];

    for (final BrowseHour h in hours) {
      if (h.dayOfWeek.toLowerCase() == name.toLowerCase()) return h;
    }

    return null;
  }
}

/// 一頁結果
class BrowsePage {
  final List<BrowseStore> items;
  final int total;
  final int page;
  final int pageSize;

  const BrowsePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < total;
}

/// GET /api/Merchant/Browse：遊客瀏覽商家與優惠券
class MerchantBrowseApi {
  const MerchantBrowseApi._();

  static String get _baseUrl {
    final String value =
        (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com').trim();

    return value.replaceFirst(RegExp(r'/$'), '');
  }

  /// 台、臺都可以，統一成「臺」
  static String normalizeCity(String value) =>
      value.trim().replaceAll('台', '臺');

  static Future<BrowsePage> browse({
    String? city,
    String? town,
    String? keyword,
    bool onlyWithCoupon = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final Map<String, String> query = {
      if ((city ?? '').trim().isNotEmpty) 'city': normalizeCity(city!),
      if ((town ?? '').trim().isNotEmpty) 'town': normalizeCity(town!),
      if ((keyword ?? '').trim().isNotEmpty) 'keyword': keyword!.trim(),
      if (onlyWithCoupon) 'only_with_coupon': 'true',
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 50)}',
    };

    final String token = (AppSession.token ?? '').trim();

    final http.Response response = await http
        .get(
          Uri.parse(
            '$_baseUrl/api/Merchant/Browse',
          ).replace(queryParameters: query),
          headers: {
            'accept': 'text/plain',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));

    dynamic decoded;

    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message = decoded is Map
          ? (decoded['message']?.toString() ?? '')
          : '';

      throw Exception(
        message.isNotEmpty ? message : '查詢商家失敗（HTTP ${response.statusCode}）',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('商家資料格式錯誤');
    }

    if (decoded['isSuccess'] != true) {
      throw Exception(decoded['message']?.toString() ?? '查詢商家失敗');
    }

    final dynamic result = decoded['Result'];

    if (result is! Map) {
      throw Exception('找不到商家資料');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(result);
    final dynamic rawItems = data['items'];

    return BrowsePage(
      items: [
        if (rawItems is List)
          for (final dynamic e in rawItems)
            if (e is Map) BrowseStore.fromJson(Map<String, dynamic>.from(e)),
      ],
      total: int.tryParse(data['total']?.toString() ?? '') ?? 0,
      page: int.tryParse(data['page']?.toString() ?? '') ?? page,
      pageSize: int.tryParse(data['page_size']?.toString() ?? '') ?? pageSize,
    );
  }
}
