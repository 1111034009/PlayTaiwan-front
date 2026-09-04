import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// 先跑明信片 ><

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
    return AiPostcardResult(
      taskId: json['task_id']?.toString() ?? '',
      postcardIntroduction: json['postcard_introduction']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
    );
  }
}

class PostcardApi {
  static String get _createAiUrl =>
      '${dotenv.env['VLOG_API_BASE_URL']}/api/postcard/create_ai';

  Future<AiPostcardResult> createAiPostcard({
    required String imagePath,
    required String spotName,
    String userPrompt = '',
  }) async {
    final Uri uri = Uri.parse(_createAiUrl);

    final http.MultipartRequest request = http.MultipartRequest('POST', uri);

    request.headers['accept'] = 'application/json';

    request.fields['spot_name'] = spotName;
    request.fields['user_prompt'] = userPrompt;
    final ByteData data = await rootBundle.load(imagePath);

    final Uint8List imageBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'user_image',
        imageBytes,
        filename: 'image-asset.webp',
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

    if (decoded['status']?.toString() != 'success') {
      throw Exception(decoded['message']?.toString() ?? 'AI 明信片建立失敗');
    }

    return AiPostcardResult.fromJson(decoded);
  }

  Future<Uint8List?> downloadAiPostcard(String downloadUrl) async {
    final Uri uri = Uri.parse(downloadUrl);

    final http.Response response = await http.get(uri);

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }

    return null;
  }
}
