import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';
import 'package:flutter/foundation.dart';

class VlogTone {
  final int id;
  final String name;

  const VlogTone({required this.id, required this.name});

  factory VlogTone.fromJson(Map<String, dynamic> json) => VlogTone(
    id: int.tryParse(json['nt_id']?.toString() ?? '') ?? 0,
    name: json['nt_name']?.toString() ?? '',
  );
}

class VlogPreview {
  final int mmId;
  final String storeName;
  final String address;
  final String toneName;
  final String script;
  final String caption;
  final List<String> hashtags;
  final List<String> imageUrls;

  const VlogPreview({
    required this.mmId,
    required this.storeName,
    required this.address,
    required this.toneName,
    required this.script,
    required this.caption,
    required this.hashtags,
    required this.imageUrls,
  });

  static List<String> _strings(dynamic raw) => raw is List
      ? raw
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
      : <String>[];

  factory VlogPreview.fromJson(Map<String, dynamic> json) => VlogPreview(
    mmId: int.tryParse(json['mm_id']?.toString() ?? '') ?? 0,
    storeName: json['store_name']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    toneName: json['tone_name']?.toString() ?? '',
    script: json['script']?.toString() ?? '',
    caption: json['caption']?.toString() ?? '',
    hashtags: _strings(json['hashtags']),
    imageUrls: _strings(json['image_urls']),
  );
}

class VlogFinalTask {
  final int mmId;
  final String taskId;
  final int status;
  final String statusText;

  const VlogFinalTask({
    required this.mmId,
    required this.taskId,
    required this.status,
    required this.statusText,
  });

  factory VlogFinalTask.fromJson(Map<String, dynamic> json) => VlogFinalTask(
    mmId: int.tryParse(json['mm_id']?.toString() ?? '') ?? 0,
    taskId: json['task_id']?.toString() ?? '',
    status: int.tryParse(json['status']?.toString() ?? '') ?? 0,
    statusText: json['status_text']?.toString() ?? '',
  );
}

class VlogStatus {
  final int status;
  final String statusText;
  final String title;
  final String videoUrl;
  final String errorMessage;

  const VlogStatus({
    required this.status,
    required this.statusText,
    required this.title,
    required this.videoUrl,
    required this.errorMessage,
  });

  bool get isCompleted => status == 3 && videoUrl.isNotEmpty;
  bool get isFailed => status == 4;

  factory VlogStatus.fromJson(Map<String, dynamic> json) => VlogStatus(
    status: int.tryParse(json['status']?.toString() ?? '') ?? 0,
    statusText: json['status_text']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    videoUrl: json['video_url']?.toString() ?? '',
    errorMessage: json['error_message']?.toString() ?? '',
  );
}

class MerchantFile {
  final int? id;
  final String title;
  final int status;
  final String updatedAt;

  const MerchantFile({
    required this.id,
    required this.title,
    required this.status,
    required this.updatedAt,
  });

  bool get isProcessing => status == 2;

  factory MerchantFile.fromJson(Map<String, dynamic> json) {
    final title = json['mm_title']?.toString().trim() ?? '';

    return MerchantFile(
      id: int.tryParse(json['mm_id']?.toString() ?? ''),
      title: title.isEmpty ? '未命名檔案' : title,
      status: int.tryParse(json['mm_status']?.toString() ?? '') ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class MerchantVlogApi {
  MerchantVlogApi._();

  static String get _base =>
      (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com')
          .trim()
          .replaceFirst(RegExp(r'/$'), '');

  static String get _token {
    final token = AppSession.token;
    if (token == null || token.isEmpty) {
      throw Exception('登入狀態已失效，請重新登入');
    }
    return token;
  }

  static Map<String, String> _headers({bool json = false}) => {
    'accept': 'text/plain',
    'Authorization': 'Bearer $_token',
    if (json) 'Content-Type': 'application/json',
  };

  static dynamic _unwrap(http.Response res) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {}

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = decoded is Map ? decoded['message']?.toString() : null;
      throw Exception(msg ?? '請求失敗（HTTP ${res.statusCode}）');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('伺服器回傳格式錯誤');
    }

    if (decoded['isSuccess'] != true) {
      throw Exception(decoded['message']?.toString() ?? '操作失敗');
    }

    return decoded['Result'];
  }

  static Future<List<MerchantFile>> fetchFiles() async {
    final res = await http
        .get(Uri.parse('$_base/api/Merchant/Files'), headers: _headers())
        .timeout(const Duration(seconds: 15));

    final result = _unwrap(res);
    if (result is! List) throw Exception('檔案資料格式錯誤');

    final files = result
        .whereType<Map>()
        .map((e) => MerchantFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    files.sort((a, b) {
      final dateA = DateTime.tryParse(a.updatedAt);
      final dateB = DateTime.tryParse(b.updatedAt);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    return files;
  }

  static Future<List<VlogTone>> fetchTones() async {
    final res = await http
        .get(Uri.parse('$_base/api/MerchantVlog/Tones'), headers: _headers())
        .timeout(const Duration(seconds: 15));

    final result = _unwrap(res);
    if (result is! List) throw Exception('語氣資料格式錯誤');

    return result
        .whereType<Map>()
        .map((e) => VlogTone.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<VlogPreview> preview({
    int? mmId,
    String? storeName,
    String? openTime,
    String? address,
    int? ntId,
    required String promoText,
    List<String> imagePaths = const [],
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/MerchantVlog/Preview'),
    )..headers.addAll(_headers());

    void add(String key, Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) req.fields[key] = text;
    }

    add('mm_id', mmId);
    add('store_name', storeName);
    add('open_time', openTime);
    add('address', address);
    add('nt_id', ntId);
    add('promo_text', promoText);

    for (final path in imagePaths) {
      req.files.add(await http.MultipartFile.fromPath('images', path));
    }

    final streamed = await req.send().timeout(const Duration(minutes: 3));
    final res = await http.Response.fromStream(streamed);

    final result = _unwrap(res);
    if (result is! Map) throw Exception('草稿資料格式錯誤');

    return VlogPreview.fromJson(Map<String, dynamic>.from(result));
  }

  static Future<VlogFinalTask> createFinal({
    required int mmId,
    required String finalScript,
    required String caption,
    required List<String> hashtags,
  }) async {
    final body = jsonEncode({
      'mm_id': mmId,
      'final_script': finalScript,
      'caption': caption,
      'hashtags': hashtags,
    });

    debugPrint('CreateFinal 送出：$body');

    final res = await http
        .post(
          Uri.parse('$_base/api/MerchantVlog/CreateFinal'),
          headers: _headers(json: true),
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    debugPrint(
      'CreateFinal 回應：${res.statusCode} ${utf8.decode(res.bodyBytes)}',
    );

    final result = _unwrap(res);
    if (result is! Map) throw Exception('任務資料格式錯誤');

    return VlogFinalTask.fromJson(Map<String, dynamic>.from(result));
  }

  static Future<VlogStatus> fetchStatus(int mmId) async {
    final res = await http
        .get(
          Uri.parse('$_base/api/MerchantVlog/Status/$mmId'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));

    final result = _unwrap(res);
    if (result is! Map) throw Exception('狀態資料格式錯誤');

    return VlogStatus.fromJson(Map<String, dynamic>.from(result));
  }
}
