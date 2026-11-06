import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class VisitorAnalysisApi {
  static String get _baseUrl =>
      (dotenv.env['API_BASE_URL'] ?? '').trim().replaceFirst(RegExp(r'/$'), '');

  static Future<VisitorAnalysisDashboard> fetchDashboard() async {
    final uri = Uri.parse('$_baseUrl/api/VisitorAnalysis');
    final response = await http.get(uri, headers: {'accept': 'application/json'});

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('客群分析查詢失敗：HTTP ${response.statusCode}\n${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['isSuccess'] != true) {
      throw Exception(body['message']?.toString() ?? '客群分析查詢失敗');
    }

    final result = body['Result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('客群分析 API 缺少 Result');
    }

    return VisitorAnalysisDashboard.fromJson(result);
  }

  /// 經營策略聊天：前端只送景點 uid + 使用者問題；system prompt / RAG 由後端處理。
  static Future<VisitorStrategyChatResult> chatStrategy({
    required String attractionUid,
    required String question,
    String? businessType,
    String? goal,
    String? budget,
    String? visitorType,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/VisitorAnalysis/Strategy/Chat');
    final response = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'attraction_uid': attractionUid,
            'question': question,
            if (businessType != null && businessType.isNotEmpty)
              'business_type': businessType,
            if (goal != null && goal.isNotEmpty) 'goal': goal,
            if (budget != null && budget.isNotEmpty) 'budget': budget,
            if (visitorType != null && visitorType.isNotEmpty)
              'visitor_type': visitorType,
          }),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '經營策略對話失敗：HTTP ${response.statusCode}\n${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['isSuccess'] != true) {
      throw Exception(body['message']?.toString() ?? '經營策略對話失敗');
    }

    final result = body['Result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('經營策略 API 缺少 Result');
    }

    return VisitorStrategyChatResult.fromJson(result);
  }

  /// 全台總覽：沒選景點時的整體圖表（後端從 Neo4j 統計，快取 30 分鐘；refresh 立即重算）
  static Future<VisitorOverview> fetchOverview({bool refresh = false}) async {
    final uri = Uri.parse(
      '$_baseUrl/api/VisitorAnalysis/Overview${refresh ? '?refresh=true' : ''}',
    );
    final response = await http
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(const Duration(minutes: 1));

    final body = _decode(response, '全台總覽查詢失敗');
    final result = body['Result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('全台總覽 API 缺少 Result');
    }
    return VisitorOverview.fromJson(result);
  }

  /// 全台問答：不帶景點；AI 不能用時後端改用統計回答（status = fallback）
  static Future<VisitorStrategyChatResult> chatOverview(String question) async {
    final uri = Uri.parse('$_baseUrl/api/VisitorAnalysis/Overview/Chat');
    final response = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'question': question}),
        )
        .timeout(const Duration(minutes: 5));

    final body = _decode(response, '全台問答失敗');
    final result = body['Result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('全台問答 API 缺少 Result');
    }
    return VisitorStrategyChatResult.fromJson(result);
  }

  static Map<String, dynamic> _decode(http.Response response, String failure) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body?['message']?.toString() ?? '$failure：HTTP ${response.statusCode}',
      );
    }
    if (body == null || body['isSuccess'] != true) {
      throw Exception(body?['message']?.toString() ?? failure);
    }
    return body;
  }
}

class VisitorStrategyChatResult {
  VisitorStrategyChatResult({
    required this.status,
    required this.message,
    this.reply,
    this.ragStatus,
    this.llmStatus,
  });

  final String status;
  final String message;
  final String? reply;
  final String? ragStatus;
  final String? llmStatus;

  factory VisitorStrategyChatResult.fromJson(Map<String, dynamic> json) {
    String? reply = json['reply']?.toString();
    if (reply == null || reply.isEmpty) {
      final strategies = json['strategies'];
      if (strategies is List && strategies.isNotEmpty) {
        final first = strategies.first;
        reply = first is String ? first : first?.toString();
      }
    }

    return VisitorStrategyChatResult(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      reply: reply,
      ragStatus: json['rag_status']?.toString(),
      llmStatus: json['llm_status']?.toString(),
    );
  }

  String displayText() {
    if ((status == 'ok' || status == 'fallback') &&
        reply != null &&
        reply!.trim().isNotEmpty) {
      return reply!.trim();
    }
    if (status == 'attraction_not_found') {
      return message.isNotEmpty
          ? message
          : '找不到對應景點，請確認此景點已匯入 Neo4j。';
    }
    if (status == 'not_ready') {
      return message.isNotEmpty
          ? '目前無法生成回覆：$message'
          : 'AI 服務尚未就緒，請稍後再試。';
    }
    return message.isNotEmpty ? message : '無法取得回覆，請稍後再試。';
  }
}

class VisitorAnalysisDashboard {
  VisitorAnalysisDashboard({
    required this.attractionCount,
    required this.domesticCount,
    required this.inboundCount,
    required this.attractions,
  });

  final int attractionCount;
  final int domesticCount;
  final int inboundCount;
  final List<VisitorAttraction> attractions;

  factory VisitorAnalysisDashboard.fromJson(Map<String, dynamic> json) {
    final list = json['attractions'] as List<dynamic>? ?? [];
    return VisitorAnalysisDashboard(
      attractionCount: (json['attraction_count'] as num?)?.toInt() ?? 0,
      domesticCount: (json['domestic_count'] as num?)?.toInt() ?? 0,
      inboundCount: (json['inbound_count'] as num?)?.toInt() ?? 0,
      attractions: list
          .whereType<Map<String, dynamic>>()
          .map(VisitorAttraction.fromJson)
          .toList(),
    );
  }
}

class VisitorAttraction {
  VisitorAttraction({
    required this.uid,
    required this.name,
    required this.city,
    this.domestic,
    this.inbound,
  });

  final String uid;
  final String name;
  final String city;
  final DomesticAnalysis? domestic;
  final InboundAnalysis? inbound;

  factory VisitorAttraction.fromJson(Map<String, dynamic> json) {
    return VisitorAttraction(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      domestic: json['domestic'] is Map<String, dynamic>
          ? DomesticAnalysis.fromJson(json['domestic'] as Map<String, dynamic>)
          : null,
      inbound: json['inbound'] is Map<String, dynamic>
          ? InboundAnalysis.fromJson(json['inbound'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DomesticAnalysis {
  DomesticAnalysis.fromJson(Map<String, dynamic> json)
      : nTrips = (json['n_trips'] as num?)?.toInt(),
        years = json['years']?.toString(),
        meanDays = (json['mean_days'] as num?)?.toDouble(),
        mainAge = json['main_age']?.toString(),
        mainAgePct = (json['main_age_pct'] as num?)?.toDouble(),
        femalePct = (json['female_pct'] as num?)?.toDouble(),
        mainPurpose = json['main_purpose']?.toString(),
        mainPurposePct = (json['main_purpose_pct'] as num?)?.toDouble(),
        purposeLeisurePct = (json['purpose_leisure_pct'] as num?)?.toDouble(),
        purposeBusinessPct = (json['purpose_business_pct'] as num?)?.toDouble(),
        purposeVfrPct = (json['purpose_vfr_pct'] as num?)?.toDouble(),
        topTransports = parseLabeledPercents(json['top_transports']?.toString()),
        topActivities = parseLabeledPercents(json['top_activities']?.toString()),
        clusterName = json['cluster_name']?.toString(),
        inCluster = (json['in_cluster'] as num?)?.toInt() ?? 0,
        ffVisitorsSum = (json['ff_visitors_sum'] as num?)?.toDouble(),
        ffVisitorsMean = (json['ff_visitors_mean'] as num?)?.toDouble(),
        ffYears = (json['ff_years'] as num?)?.toInt();

  final int? nTrips;
  final String? years;
  final double? meanDays;
  final String? mainAge;
  final double? mainAgePct;
  final double? femalePct;
  final String? mainPurpose;
  final double? mainPurposePct;
  final double? purposeLeisurePct;
  final double? purposeBusinessPct;
  final double? purposeVfrPct;
  final Map<String, double> topTransports;
  final Map<String, double> topActivities;
  final String? clusterName;
  final int inCluster;
  final double? ffVisitorsSum;
  final double? ffVisitorsMean;
  final int? ffYears;

  Map<String, double> get purposes => {
        if (purposeLeisurePct != null) '休閒／觀光': purposeLeisurePct!,
        if (purposeBusinessPct != null) '商公務': purposeBusinessPct!,
        if (purposeVfrPct != null) '探訪親友': purposeVfrPct!,
      };
}

class InboundAnalysis {
  InboundAnalysis.fromJson(Map<String, dynamic> json)
      : nTrips = (json['n_trips'] as num?)?.toInt(),
        years = json['years']?.toString(),
        meanDays = (json['mean_days'] as num?)?.toDouble(),
        meanNights = (json['mean_nights'] as num?)?.toDouble(),
        mainAge = json['main_age']?.toString(),
        mainAgePct = (json['main_age_pct'] as num?)?.toDouble(),
        femalePct = (json['female_pct'] as num?)?.toDouble(),
        ageU29Pct = (json['age_u29_pct'] as num?)?.toDouble(),
        age3049Pct = (json['age_3049_pct'] as num?)?.toDouble(),
        age50pPct = (json['age_50p_pct'] as num?)?.toDouble(),
        mainPurpose = json['main_purpose']?.toString(),
        mainPurposePct = (json['main_purpose_pct'] as num?)?.toDouble(),
        purposeSightseeingPct = (json['purpose_sightseeing_pct'] as num?)?.toDouble(),
        purposeBusinessPct = (json['purpose_business_pct'] as num?)?.toDouble(),
        purposeVfrPct = (json['purpose_vfr_pct'] as num?)?.toDouble(),
        topTransports = parseLabeledPercents(json['top_transports']?.toString()),
        topActivities = parseLabeledPercents(json['top_activities']?.toString()),
        clusterName = json['cluster_name']?.toString(),
        inCluster = (json['in_cluster'] as num?)?.toInt() ?? 0,
        ffVisitorsSum = (json['ff_visitors_sum'] as num?)?.toDouble(),
        ffVisitorsMean = (json['ff_visitors_mean'] as num?)?.toDouble(),
        ffYears = (json['ff_years'] as num?)?.toInt();

  final int? nTrips;
  final String? years;
  final double? meanDays;
  final double? meanNights;
  final String? mainAge;
  final double? mainAgePct;
  final double? femalePct;
  final double? ageU29Pct;
  final double? age3049Pct;
  final double? age50pPct;
  final String? mainPurpose;
  final double? mainPurposePct;
  final double? purposeSightseeingPct;
  final double? purposeBusinessPct;
  final double? purposeVfrPct;
  final Map<String, double> topTransports;
  final Map<String, double> topActivities;
  final String? clusterName;
  final int inCluster;
  final double? ffVisitorsSum;
  final double? ffVisitorsMean;
  final int? ffYears;

  Map<String, double> get ages => {
        if (ageU29Pct != null) '29歲以下': ageU29Pct!,
        if (age3049Pct != null) '30–49歲': age3049Pct!,
        if (age50pPct != null) '50歲以上': age50pPct!,
      };

  Map<String, double> get purposes => {
        if (purposeSightseeingPct != null) '觀光': purposeSightseeingPct!,
        if (purposeBusinessPct != null) '商務': purposeBusinessPct!,
        if (purposeVfrPct != null) '探親訪友': purposeVfrPct!,
      };
}

/// 全台總覽（Neo4j 統計）
class VisitorOverview {
  VisitorOverview.fromJson(Map<String, dynamic> json)
      : generatedAt = DateTime.tryParse(json['generated_at']?.toString() ?? ''),
        totals = VisitorOverviewTotals.fromJson(_map(json['totals'])),
        cities = _list(json['cities']).map(VisitorOverviewCity.fromJson).toList(),
        domestic = VisitorOverviewProfile.fromJson(_map(json['domestic'])),
        inbound = VisitorOverviewProfile.fromJson(_map(json['inbound'])),
        hotelClasses = _values(json['hotel_classes']),
        attractionCategories = _values(json['attraction_categories']),
        eventMonths = _values(json['event_months']),
        topFootfall =
            _list(json['top_footfall']).map(VisitorOverviewFootfall.fromJson).toList(),
        insights = _list(json['insights']).map(VisitorOverviewInsight.fromJson).toList();

  final DateTime? generatedAt;
  final VisitorOverviewTotals totals;
  final List<VisitorOverviewCity> cities;
  final VisitorOverviewProfile domestic;
  final VisitorOverviewProfile inbound;
  final Map<String, double> hotelClasses;
  final Map<String, double> attractionCategories;
  final Map<String, double> eventMonths;
  final List<VisitorOverviewFootfall> topFootfall;
  final List<VisitorOverviewInsight> insights;
}

class VisitorOverviewTotals {
  VisitorOverviewTotals.fromJson(Map<String, dynamic> json)
      : attractions = _int(json['attractions']),
        restaurants = _int(json['restaurants']),
        hotels = _int(json['hotels']),
        events = _int(json['events']),
        cities = _int(json['cities']),
        analyzedAttractions = _int(json['analyzed_attractions']),
        domesticAttractions = _int(json['domestic_attractions']),
        inboundAttractions = _int(json['inbound_attractions']),
        footfallAttractions = _int(json['footfall_attractions']);

  final int attractions;
  final int restaurants;
  final int hotels;
  final int events;
  final int cities;
  final int analyzedAttractions;
  final int domesticAttractions;
  final int inboundAttractions;
  final int footfallAttractions;
}

class VisitorOverviewCity {
  VisitorOverviewCity.fromJson(Map<String, dynamic> json)
      : city = json['city']?.toString() ?? '',
        attractions = _int(json['attractions']),
        restaurants = _int(json['restaurants']),
        hotels = _int(json['hotels']),
        events = _int(json['events']),
        hotelsPerAttraction = _double(json['hotels_per_attraction']) ?? 0,
        analyzedAttractions = _int(json['analyzed_attractions']),
        analyzedPct = _double(json['analyzed_pct']) ?? 0,
        surveyTrips = _int(json['survey_trips']),
        footfallMeanSum = _double(json['footfall_mean_sum']) ?? 0;

  final String city;
  final int attractions;
  final int restaurants;
  final int hotels;
  final int events;
  final double hotelsPerAttraction;
  final int analyzedAttractions;
  final double analyzedPct;
  final int surveyTrips;
  final double footfallMeanSum;
}

class VisitorOverviewProfile {
  VisitorOverviewProfile.fromJson(Map<String, dynamic> json)
      : attractions = _int(json['attractions']),
        trips = _int(json['trips']),
        femalePct = _double(json['female_pct']),
        meanDays = _double(json['mean_days']),
        meanNights = _double(json['mean_nights']),
        mainAges = _values(json['main_ages']),
        ageShares = _values(json['age_shares']),
        purposes = _values(json['purposes']),
        transports = _values(json['transports']),
        activities = _values(json['activities']),
        clusters = _values(json['clusters']);

  final int attractions;
  final int trips;
  final double? femalePct;
  final double? meanDays;
  final double? meanNights;

  /// 各景點的主要年齡層（值 = 景點數）
  final Map<String, double> mainAges;

  /// 年齡結構（值 = %）；只有來臺有
  final Map<String, double> ageShares;
  final Map<String, double> purposes;

  /// 列在該景點前三名的景點占比（%）
  final Map<String, double> transports;
  final Map<String, double> activities;

  /// 旅客分群（值 = 景點數）
  final Map<String, double> clusters;
}

class VisitorOverviewFootfall {
  VisitorOverviewFootfall.fromJson(Map<String, dynamic> json)
      : uid = json['uid']?.toString() ?? '',
        name = json['name']?.toString() ?? '',
        city = json['city']?.toString() ?? '',
        visitorsMean = _double(json['visitors_mean']) ?? 0;

  final String uid;
  final String name;
  final String city;
  final double visitorsMean;
}

class VisitorOverviewInsight {
  VisitorOverviewInsight.fromJson(Map<String, dynamic> json)
      : topic = json['topic']?.toString() ?? '',
        title = json['title']?.toString() ?? '',
        text = json['text']?.toString() ?? '';

  final String topic;
  final String title;
  final String text;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

List<Map<String, dynamic>> _list(dynamic value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

int _int(dynamic value) => (value as num?)?.toInt() ?? 0;

double? _double(dynamic value) => (value as num?)?.toDouble();

/// [{label, value}, …] → 保留順序的 Map
Map<String, double> _values(dynamic value) => {
      for (final item in _list(value))
        if ((item['label']?.toString() ?? '').isNotEmpty)
          item['label'].toString(): _double(item['value']) ?? 0,
    };

/// 解析「自用汽車 81.3%；遊覽車 10.9%」這類字串
Map<String, double> parseLabeledPercents(String? raw) {
  final result = <String, double>{};
  if (raw == null || raw.trim().isEmpty) return result;

  for (final part in raw.split('；')) {
    final text = part.trim();
    if (text.isEmpty) continue;
    final match = RegExp(r'^(.+?)\s+([\d.]+)%$').firstMatch(text);
    if (match == null) continue;
    result[match.group(1)!.trim()] = double.parse(match.group(2)!);
  }
  return result;
}