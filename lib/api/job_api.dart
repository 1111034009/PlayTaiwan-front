import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';

/// 使用者取消了這個工作（或後端回 cancelled）
class JobCancelled implements Exception {
  @override
  String toString() => '已取消生成';
}

/// 後端「Job」的一次回報（POST xxxJob 和 GET xxxJob/{job_id} 長一樣）：
/// { job_id, status: processing | done | failed | cancelled, stage, queue_position, error, result }
class JobInfo {
  final String jobId;
  final String status;
  final String stage;
  final int? queuePosition;
  final String error;
  final dynamic result;

  const JobInfo({
    required this.jobId,
    required this.status,
    required this.stage,
    required this.queuePosition,
    required this.error,
    required this.result,
  });

  factory JobInfo.fromJson(Map<String, dynamic> json) => JobInfo(
    jobId: json['job_id']?.toString().trim() ?? '',
    status: json['status']?.toString().trim() ?? '',
    stage: json['stage']?.toString().trim() ?? '',
    queuePosition: int.tryParse(json['queue_position']?.toString() ?? ''),
    error: json['error']?.toString().trim() ?? '',
    result: json['result'],
  );

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';

  /// 等待畫面上顯示的字：排隊中會寫前面還有幾個，不然就是目前的階段
  String get waitingText {
    final int? position = queuePosition;

    if (position != null && position > 0) {
      return '排隊中，前面還有 $position 個…';
    }

    return stage.isNotEmpty ? '$stage…' : '生成中…';
  }
}

/// 所有「送出 → 拿 job_id → 每 3 秒查一次 → done 拿結果」的後端工作共用這裡：
/// 遊客／商家 VLOG 草稿、AI 明信片、回顧旁白語音。
/// AI 做好之前後端不會寫資料庫，取消或失敗都不會留下東西。
class JobApi {
  JobApi._();

  static const Duration pollInterval = Duration(seconds: 3);

  /// 連續查幾次都失敗（網路斷斷續續）才放棄
  static const int _maxPollErrors = 4;

  static String get baseUrl =>
      (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com')
          .trim()
          .replaceFirst(RegExp(r'/$'), '');

  static String get token {
    final String? value = AppSession.token;

    if (value == null || value.isEmpty) {
      throw Exception('登入狀態已失效，請重新登入');
    }

    return value;
  }

  static Map<String, String> headers({bool json = false}) => {
    'accept': 'text/plain',
    'Authorization': 'Bearer $token',
    if (json) 'Content-Type': 'application/json',
  };

  /// POST JSON 送出工作
  static Future<JobInfo> startJson(
    String path,
    Map<String, dynamic> body, {
    required String failMessage,
  }) async {
    final http.Response response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    return parse(response, failMessage: failMessage);
  }

  /// 把 HTTP 回應轉成 [JobInfo]。
  /// 注意：failed 的時候後端回 isSuccess=false 但 Result 還是有 status／error，所以有 Result 就以 Result 為準
  static JobInfo parse(http.Response response, {required String failMessage}) {
    dynamic decoded;

    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {}

    final dynamic result = decoded is Map ? decoded['Result'] : null;
    final String message = decoded is Map
        ? (decoded['message']?.toString().trim() ?? '')
        : '';

    if (response.statusCode == 404) {
      throw Exception('找不到這個工作（可能已過期），請重新產生');
    }

    if (result is Map && result['status'] != null) {
      return JobInfo.fromJson(Map<String, dynamic>.from(result));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        message.isNotEmpty
            ? message
            : '$failMessage（HTTP ${response.statusCode}）',
      );
    }

    throw Exception(message.isNotEmpty ? message : failMessage);
  }

  /// 一直查到 done，回傳 result；failed 丟出 error 的文字、cancelled 丟 [JobCancelled]。
  /// [pollPath] 給 job_id 回傳要查的路徑；[onProgress] 每次查完都會叫（可顯示 stage／排隊人數）
  static Future<dynamic> waitForResult(
    JobInfo first, {
    required String Function(String jobId) pollPath,
    required String failMessage,
    void Function(JobInfo job)? onProgress,
    void Function(String jobId)? onJobId,
    Duration timeout = const Duration(minutes: 15),
  }) async {
    JobInfo job = first;

    if (job.jobId.isEmpty) {
      throw Exception('$failMessage：沒有回傳 job_id');
    }

    onJobId?.call(job.jobId);

    final DateTime deadline = DateTime.now().add(timeout);
    int errors = 0;

    while (true) {
      onProgress?.call(job);

      if (job.isCancelled) throw JobCancelled();

      if (job.isDone) return job.result;

      if (job.isFailed) {
        throw Exception(job.error.isNotEmpty ? job.error : failMessage);
      }

      if (DateTime.now().isAfter(deadline)) {
        throw Exception('$failMessage：等待逾時，請重新產生');
      }

      await Future<void>.delayed(pollInterval);

      try {
        final http.Response response = await http
            .get(
              Uri.parse('$baseUrl${pollPath(job.jobId)}'),
              headers: headers(),
            )
            .timeout(const Duration(seconds: 20));

        job = parse(response, failMessage: failMessage);
        errors = 0;
      } on TimeoutException {
        if (++errors >= _maxPollErrors) {
          throw Exception('$failMessage：連線逾時');
        }
      } on http.ClientException {
        if (++errors >= _maxPollErrors) {
          throw Exception('$failMessage：網路連線中斷');
        }
      }
    }
  }

  /// POST .../Cancel。已經做好（回 isSuccess=false、status=done）就不用管，照常拿結果。
  /// 失敗不丟錯：離開頁面時呼叫，不能因此卡住
  static Future<void> cancel(String path) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers(json: true),
            body: '',
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }
}
