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
    if (status == 'ok' && reply != null && reply!.trim().isNotEmpty) {
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