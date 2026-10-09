import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';

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

    return AiPostcardResult(
      taskId: resultData['PostcardId']?.toString() ?? '',
      postcardIntroduction: resultData['Summary']?.toString() ?? '',
      downloadUrl: resultData['ImageUrl']?.toString() ?? '',
    );
  }
}

class PostcardApi {
  static String get _createAiUrl =>
      '${dotenv.env['API_BASE_URL']}/api/PostcardCatalog/GenerateAi';

  static String get _printUrl =>
      '${dotenv.env['API_BASE_URL']}/api/PostcardCatalog/Print';

  Future<AiPostcardResult> createAiPostcard({
    required String imagePath,
    required String spotName,
    String userPrompt = '',
    required String storyId,
    required bool isNightEdition,
  }) async {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('尚未取得登入 Token');
    }

    final File imageFile = File(imagePath);

    if (!await imageFile.exists()) {
      throw Exception('找不到圖片檔案：$imagePath');
    }

    final Uint8List imageBytes = await imageFile.readAsBytes();

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

    request.files.add(
      http.MultipartFile.fromBytes(
        'user_image',
        imageBytes,
        filename: imageFile.uri.pathSegments.last,
      ),
    );

    final http.StreamedResponse streamedResponse = await request.send();

    final http.Response response = await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AI 明信片建立失敗\n'
        'Status Code: ${response.statusCode}\n'
        'Response: ${response.body}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('AI 明信片 API 回傳格式錯誤');
    }

    if (decoded['isSuccess'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'AI 明信片建立失敗');
    }

    final AiPostcardResult result = AiPostcardResult.fromJson(decoded);

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
