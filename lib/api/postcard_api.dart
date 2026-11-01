import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';
import 'job_api.dart';

class AiPostcardResult {
  final String taskId;
  final String postcardIntroduction;
  final String downloadUrl;

  const AiPostcardResult({
    required this.taskId,
    required this.postcardIntroduction,
    required this.downloadUrl,
  });

  factory AiPostcardResult.fromJson(Map<String, dynamic> json) {
    final dynamic resultData = json['Result'];

    if (resultData is! Map<String, dynamic>) {
      throw Exception('AI 明信片 API 缺少 Result');
    }

    // 後端現在回的欄位是 p_id、p_summary、p_imag_url（明信片的顯示網址）；舊的欄位名稱也認
    return AiPostcardResult(
      taskId: (resultData['PostcardId'] ?? resultData['p_id'])?.toString() ?? '',
      postcardIntroduction:
          (resultData['Summary'] ?? resultData['p_summary'])?.toString() ?? '',
      downloadUrl:
          (resultData['ImageUrl'] ??
                  resultData['p_imag_url'] ??
                  resultData['download_url'])
              ?.toString() ??
          '',
    );
  }
}

class PostcardApi {
  /// GET /api/PostcardCatalog/{id}：分享時一起帶的文字（ShareText）；拿不到回空字串
  static Future<String> fetchShareText(String postcardId) async {
    final String? token = AppSession.token;
    final String id = postcardId.trim();

    if (token == null || token.isEmpty || id.isEmpty) return '';

    try {
      final http.Response response = await http.get(
        Uri.parse(
          '${dotenv.env['API_BASE_URL']}/api/PostcardCatalog/${Uri.encodeComponent(id)}',
        ),
        headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) return '';

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      final dynamic result = data is Map ? data['Result'] : null;

      if (result is! Map) return '';

      return (result['ShareText'] ?? result['Summary'])?.toString().trim() ??
          '';
    } catch (_) {
      return '';
    }
  }

  static String get _createAiUrl =>
      '${dotenv.env['API_BASE_URL']}/api/PostcardCatalog/GenerateAiJob';

  static String get _printUrl =>
      '${dotenv.env['API_BASE_URL']}/api/PostcardCatalog/Print';

  /// AI 明信片（Job 模式）：POST /api/PostcardCatalog/GenerateAiJob（欄位跟舊的 GenerateAi 一樣）拿 job_id →
  /// 每 3 秒 GET /api/PostcardCatalog/GenerateAiJob/{job_id}，done 的 result 就是明信片（p_id、p_summary、p_imag_url…）。
  /// [onProgress] 給等待畫面顯示階段／排隊人數；[onJobId] 拿到 job_id 後叫。
  ///
  /// 照片可以給檔案路徑 [imagePath]，或直接給內容 [imageBytes]（玩家剛拍的照片、網頁版沒有檔案路徑時用）。
  /// [nodeId] 是拿到這張明信片的劇本節點，有給後端才知道是哪一關的
  Future<AiPostcardResult> createAiPostcard({
    String imagePath = '',
    Uint8List? imageBytes,
    String imageName = 'photo.jpg',
    required String spotName,
    String userPrompt = '',
    required String storyId,
    String nodeId = '',
    required bool isNightEdition,
    void Function(JobInfo job)? onProgress,
    void Function(String jobId)? onJobId,
  }) async {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('尚未取得登入 Token');
    }

    final Uint8List userImage;
    final String userImageName;

    if (imageBytes != null) {
      userImage = imageBytes;
      userImageName = imageName;
    } else {
      final File imageFile = File(imagePath);

      if (!await imageFile.exists()) {
        throw Exception('找不到圖片檔案：$imagePath');
      }

      userImage = await imageFile.readAsBytes();
      userImageName = imageFile.uri.pathSegments.last;
    }

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse(_createAiUrl),
    );

    request.headers['accept'] = 'text/plain';
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['spot_name'] = spotName;
    request.fields['user_prompt'] = userPrompt;
    request.fields['story_id'] = storyId;
    request.fields['is_night_edition'] = isNightEdition.toString();

    if (nodeId.isNotEmpty) {
      request.fields['node_id'] = nodeId;
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'user_image',
        userImage,
        filename: userImageName,
      ),
    );

    final http.StreamedResponse streamedResponse = await request.send();

    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    const String failMessage = 'AI 明信片建立失敗';

    // 這一步只是送出工作；做好的明信片在 job 的 result 裡
    final JobInfo first = JobApi.parse(response, failMessage: failMessage);

    final dynamic jobResult = await JobApi.waitForResult(
      first,
      pollPath: (id) =>
          '/api/PostcardCatalog/GenerateAiJob/${Uri.encodeComponent(id)}',
      failMessage: failMessage,
      onProgress: onProgress,
      onJobId: onJobId,
    );

    if (jobResult is! Map) {
      throw Exception('AI 明信片 API 回傳格式錯誤');
    }

    final AiPostcardResult result = AiPostcardResult.fromJson({
      'Result': Map<String, dynamic>.from(jobResult),
    });

    if (result.downloadUrl.isEmpty) {
      throw Exception('AI 明信片 API 未回傳 ImageUrl');
    }

    return result;
  }

  Future<Uint8List?> downloadAiPostcard(String downloadUrl) async {
    if (downloadUrl.isEmpty) {
      return null;
    }

    final http.Response response = await http.get(
      Uri.parse(downloadUrl),
      headers: {'accept': 'text/plain'},
    );

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }

    return null;
  }

  // ============================================================
  // ibon 實體列印
  // ============================================================

  Future<Map<String, dynamic>> printPostcard({
    required String postcardId,
  }) async {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('尚未取得登入 Token');
    }

    if (postcardId.isEmpty) {
      throw Exception('找不到明信片 ID');
    }

    final http.Response response = await http.post(
      Uri.parse(_printUrl),
      headers: {
        'accept': 'text/plain',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'postcard_id': postcardId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '取得 ibon 取件碼失敗\n'
        'Status Code: ${response.statusCode}\n'
        'Response: ${response.body}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('ibon API 回傳格式錯誤');
    }

    if (decoded['isSuccess'] != true) {
      throw Exception(decoded['message']?.toString() ?? '取得 ibon 取件碼失敗');
    }

    final dynamic result = decoded['Result'];

    if (result is! Map) {
      throw Exception('ibon API Result 格式錯誤');
    }

    return Map<String, dynamic>.from(result);
  }
}
