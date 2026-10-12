import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';

class PairApi {
  static String get _baseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    required String failMessage,
    Map<String, dynamic>? body,
    Map<int, String> statusMessages = const {},
  }) async {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入資訊已失效，請重新登入');
    }

    final Uri uri = Uri.parse('$_baseUrl$path');

    final Map<String, String> headers = {
      'accept': 'text/plain',
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final response = method == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));

    dynamic data;

    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }

    final String serverMessage = data is Map
        ? (data['message']?.toString().trim() ?? '')
        : '';

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        statusMessages[response.statusCode] ??
            (serverMessage.isNotEmpty
                ? serverMessage
                : '$failMessage：HTTP ${response.statusCode}'),
      );
    }

    if (data is! Map<String, dynamic> || data['isSuccess'] != true) {
      throw Exception(serverMessage.isNotEmpty ? serverMessage : failMessage);
    }

    return data;
  }

  static Map<String, dynamic> _pairResult(Map<String, dynamic> data) {
    final dynamic result = data['Result'];

    if (result is! Map) {
      throw Exception('隊伍資料格式錯誤');
    }

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> createCode({
    required String storyId,
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/api/Pair/Code',
      failMessage: '產生配對碼失敗',
      body: {'story_id': int.tryParse(storyId) ?? storyId},
      statusMessages: {409: '隊伍已滿，或此劇本為單人劇本'},
    );

    return _pairResult(data);
  }

  static Future<Map<String, dynamic>> join({required String pairCode}) async {
    final Map<String, dynamic> data = await _request(
      method: 'POST',
      path: '/api/Pair/Join',
      failMessage: '加入隊伍失敗',
      body: {'pair_code': pairCode},
      statusMessages: {404: '配對碼錯誤或已逾期', 409: '隊伍已滿'},
    );

    return _pairResult(data);
  }

  static Future<Map<String, dynamic>?> getByStory({
    required String storyId,
  }) async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/api/Pair/Story/${Uri.encodeComponent(storyId)}',
      failMessage: '取得隊伍資料失敗',
    );

    final dynamic result = data['Result'];

    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  static Future<void> leave({required String storyId}) async {
    await _request(
      method: 'POST',
      path: '/api/Pair/Leave',
      failMessage: '退出隊伍失敗',
      body: {'story_id': int.tryParse(storyId) ?? storyId},
      statusMessages: {409: '隊長無法退出，請改用取消隊伍'},
    );
  }

  static Future<void> cancel({required String storyId}) async {
    await _request(
      method: 'POST',
      path: '/api/Pair/Cancel',
      failMessage: '取消隊伍失敗',
      body: {'story_id': int.tryParse(storyId) ?? storyId},
    );
  }

  static Future<Map<String, dynamic>?> currentPlaying() async {
    final Map<String, dynamic> data = await _request(
      method: 'GET',
      path: '/api/Story/CurrentPlaying',
      failMessage: '取得目前進行劇本失敗',
    );

    final dynamic result = data['Result'];

    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  static Future<void> endStory({required String storyId}) async {
    await _request(
      method: 'POST',
      path: '/api/Story/EndStory',
      failMessage: '結束劇本失敗',
      body: {'story_id': int.tryParse(storyId) ?? storyId},
    );
  }
}
