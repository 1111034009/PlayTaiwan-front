import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/app_session.dart';

class StoryApi {
  static String get _baseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static Future<Map<String, dynamic>> generateScriptBlueprint({
    required String cityName,
    String? townName,
    required int travelerCount,
    required List<String> preferences,
    required List<String> transportation,
    int nodeCount = 4,
    bool isNight = false,
    int storyCount = 3,
  }) async {
    final String cleanCityName = cityName.trim();

    final String? cleanTownName = townName?.trim().isNotEmpty == true
        ? townName!.trim()
        : null;

    if (cleanCityName.isEmpty) {
      throw Exception('city_name 不能為空');
    }

    final Map<String, dynamic> requestBody = {
      'city_name': cleanCityName,
      'traveler_count': travelerCount,
      'preferences': preferences,
      'transportation': transportation,
      'node_count': nodeCount,
      'is_night': isNight,
      'story_count': storyCount,
    };

    if (cleanTownName != null) {
      requestBody['town_name'] = cleanTownName;
    }

    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入資訊已失效，請重新登入');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/Story/GenerateByLocation'),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('劇本生成失敗：HTTP ${response.statusCode}\n${response.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['isSuccess'] != true) {
      throw Exception(data['message']?.toString() ?? '劇本生成失敗');
    }

    return data;
  }

  static Future<Map<String, dynamic>> speakNpc({required String text}) async {
    final String cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw Exception('NPC 語音文字不能為空');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/npc/speak'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'text': cleanText, 'voice': 'zh-TW-HsiaoChenNeural'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'NPC 語音生成失敗：HTTP ${response.statusCode}\n${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'success') {
      throw Exception(data['message']?.toString() ?? 'NPC 語音生成失敗');
    }

    return data;
  }

  static Future<String> downloadNpcVoice({
    required String downloadUrl,
    required String taskId,
  }) async {
    final Directory directory = await getApplicationDocumentsDirectory();

    final Directory voiceDirectory = Directory('${directory.path}/npc_voice');

    if (!await voiceDirectory.exists()) {
      await voiceDirectory.create(recursive: true);
    }

    final File file = File('${voiceDirectory.path}/npc_$taskId.mp3');

    if (await file.exists()) {
      final int fileSize = await file.length();

      if (fileSize > 0) {
        return file.path;
      }
    }

    final response = await http.get(Uri.parse(downloadUrl));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('NPC 語音下載失敗：HTTP ${response.statusCode}');
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('NPC 語音下載失敗：檔案為空');
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);

    return file.path;
  }

  static Future<String> prepareNpcVoice({required String text}) async {
    final String cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw Exception('NPC 語音文字不能為空');
    }

    final Map<String, dynamic> result = await speakNpc(text: cleanText);

    final String downloadUrl = result['download_url']?.toString().trim() ?? '';

    final String taskId = result['task_id']?.toString().trim() ?? '';

    if (downloadUrl.isEmpty) {
      throw Exception('NPC 語音 API 沒有回傳 download_url');
    }

    if (taskId.isEmpty) {
      throw Exception('NPC 語音 API 沒有回傳 task_id');
    }

    return downloadNpcVoice(downloadUrl: downloadUrl, taskId: taskId);
  }

  static Future<Map<String, dynamic>> confirmStory({
    required String storyId,
  }) async {
    final String cleanStoryId = storyId.trim();

    if (cleanStoryId.isEmpty) {
      throw Exception('story_id 不能為空');
    }

    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入資訊已失效，請重新登入');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/Story/Confirm'),
      headers: {
        'accept': '*/*',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'story_id': cleanStoryId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('劇本確認失敗：HTTP ${response.statusCode}\n${response.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['isSuccess'] != true) {
      throw Exception(data['message']?.toString() ?? '劇本確認失敗');
    }

    return data;
  }
}
