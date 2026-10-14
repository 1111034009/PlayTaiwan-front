import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/app_session.dart';

class StoryApi {
  static String get _baseUrl {
    final String baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static String get Vlog_baseUrl {
    final String baseUrl = (dotenv.env['VLOG_API_BASE_URL'] ?? '').trim();

    return baseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static Future<({double lat, double lng})> geocodeLocation({
    required String cityName,
    String? townName,
  }) async {
    final String city = cityName.trim();
    final String town = townName?.trim() ?? '';

    final List<String> queries = [
      if (town.isNotEmpty) '$city$town',
      if (town.isNotEmpty) '${city.replaceAll('台', '臺')}$town',
      city,
      city.replaceAll('台', '臺'),
    ];

    for (final String q in queries) {
      final Uri uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'tw',
        'accept-language': 'zh-TW',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'playtaiwan-app/1.0'},
      );

      if (response.statusCode != 200) continue;

      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty) continue;

      final Map<String, dynamic> first = list.first as Map<String, dynamic>;
      final double? lat = double.tryParse(first['lat']?.toString() ?? '');
      final double? lng = double.tryParse(first['lon']?.toString() ?? '');

      if (lat != null && lng != null) {
        return (lat: lat, lng: lng);
      }
    }

    throw Exception('找不到「$city$town」的位置，請重新選擇');
  }

  static Future<Map<String, dynamic>> generateScriptBlueprint({
    required String cityName,
    String? townName,
    required int travelerCount,
    required List<String> preferences,
    required List<String> transportation,
    int isNight = 1,
  }) async {
    final String cleanCityName = cityName.trim();

    if (cleanCityName.isEmpty) {
      throw Exception('city_name 不能為空');
    }

    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入資訊已失效，請重新登入');
    }

    final location = await geocodeLocation(
      cityName: cleanCityName,
      townName: townName,
    );

    final Map<String, dynamic> requestBody = {
      'lat': location.lat,
      'lng': location.lng,
      'party_size': travelerCount,
      'transportation': transportation,
      'preferences': preferences,
      'is_night_mode': isNight,
    };
    debugPrint('requestBody: $requestBody');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/Story/GenerateGameStory'),
      headers: {
        'accept': 'text/plain',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('劇本生成失敗，請稍後再試');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['isSuccess'] != true) {
      throw Exception(data['message']?.toString() ?? '劇本生成失敗');
    }

    return data;
  }

  static Future<String> _downloadAudio(String audioUrl) async {
    final Uri uri = Uri.parse(audioUrl);

    final String fileName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'npc_${audioUrl.hashCode}.mp3';

    final Directory directory = await getTemporaryDirectory();
    final Directory voiceDirectory = Directory('${directory.path}/npc_voice');

    if (!await voiceDirectory.exists()) {
      await voiceDirectory.create(recursive: true);
    }

    final File file = File('${voiceDirectory.path}/$fileName');

    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('語音下載失敗：HTTP ${response.statusCode}');
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('語音下載失敗：檔案為空');
    }

    await file.writeAsBytes(response.bodyBytes, flush: true);

    return file.path;
  }

  static Future<String> _downloadResultAudio(
    Map<String, dynamic> data,
    String failMessage,
  ) {
    final dynamic result = data['Result'];
    final String audioUrl = result is Map
        ? (result['audio_url']?.toString().trim() ?? '')
        : '';

    if (audioUrl.isEmpty) {
      throw Exception('$failMessage：沒有回傳 audio_url');
    }

    return _downloadAudio(audioUrl);
  }

  static Future<String> preparePrologueVoice({required String storyId}) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/Npc/Prologue/${_cleanStoryId(storyId)}',
      failMessage: '前傳語音產生失敗',
    );

    return _downloadResultAudio(data, '前傳語音產生失敗');
  }

  static Future<String> prepareNpcVoice({
    required String text,
    String voice = 'zh-TW-HsiaoChenNeural',
  }) async {
    final String cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw Exception('NPC 語音文字不能為空');
    }

    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/Npc/Speak',
      failMessage: 'NPC 語音產生失敗',
      body: {'text': cleanText, 'voice': voice},
    );

    return _downloadResultAudio(data, 'NPC 語音產生失敗');
  }

  static Future<Map<String, dynamic>> getCurrentPlaying() async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'GET',
      path: '/api/Story/CurrentPlaying',
      failMessage: '取得目前進行劇本失敗',
    );

    final dynamic result = data['Result'];

    if (result is! Map) {
      throw Exception('目前沒有進行中的劇本');
    }

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getStoryFullDetail({
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

    final String encodedStoryId = Uri.encodeComponent(cleanStoryId);

    final response = await http.get(
      Uri.parse('$_baseUrl/api/Story/$encodedStoryId/FullDetail'),
      headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('取得完整劇本失敗：HTTP ${response.statusCode}\n${response.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['isSuccess'] != true) {
      throw Exception(data['message']?.toString() ?? '取得完整劇本失敗');
    }

    return data;
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
        'accept': 'text/plain',
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

  static String _requireToken() {
    final String? token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('登入資訊已失效，請重新登入');
    }

    return token;
  }

  static String _cleanStoryId(String storyId) {
    final String cleanStoryId = storyId.trim();

    if (cleanStoryId.isEmpty) {
      throw Exception('story_id 不能為空');
    }

    return Uri.encodeComponent(cleanStoryId);
  }

  static Future<Map<String, dynamic>> _storyRequest({
    required String method,
    required String path,
    required String failMessage,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl$path');

    final Map<String, String> headers = {
      'accept': 'text/plain',
      'Authorization': 'Bearer ${_requireToken()}',
      'Content-Type': 'application/json',
    };

    final response = method == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$failMessage：HTTP ${response.statusCode}');
    }

    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));

    if (data is! Map<String, dynamic> || data['isSuccess'] != true) {
      throw Exception(
        data is Map
            ? (data['message']?.toString() ?? failMessage)
            : failMessage,
      );
    }

    return data;
  }

  static Future<void> setFavorite({
    required String storyId,
    required bool isFavorite,
  }) async {
    await _storyRequest(
      method: 'POST',
      path: '/api/Story/${_cleanStoryId(storyId)}/Favorite',
      failMessage: isFavorite ? '加入喜愛失敗' : '取消喜愛失敗',
      body: {'is_favorite': isFavorite},
    );
  }

  static Future<List<Map<String, dynamic>>> getFavoriteStories() async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'GET',
      path: '/api/Story/Favorites',
      failMessage: '取得喜愛劇本失敗',
    );

    final dynamic result = data['Result'];

    if (result is! List) return [];

    return result
        .whereType<Map>()
        .map((story) => Map<String, dynamic>.from(story))
        .toList();
  }

  static Future<String> createCalendarLink({required String storyId}) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/Story/${_cleanStoryId(storyId)}/Calendar',
      failMessage: '產生行事曆連結失敗',
    );

    final dynamic result = data['Result'];
    final String url = result is Map
        ? (result['google_calendar_url']?.toString().trim() ?? '')
        : '';

    if (url.isEmpty) {
      throw Exception('行事曆 API 沒有回傳連結');
    }

    return url;
  }

  static Future<Map<String, dynamic>> getStoryDetail({
    required String storyId,
  }) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'GET',
      path: '/api/Story/${_cleanStoryId(storyId)}/Detail',
      failMessage: '取得劇本詳細內容失敗',
    );

    final dynamic result = data['Result'];

    if (result is! Map) {
      throw Exception('取得劇本詳細內容失敗');
    }

    return Map<String, dynamic>.from(result);
  }

  //遊你說了算 -一句話生成劇本
  static Future<Map<String, dynamic>> generateByText({
    required String userPrompt,
  }) async {
    final String prompt = userPrompt.trim();

    if (prompt.isEmpty) {
      throw Exception('請輸入想要的旅程描述');
    }

    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/Story/GenerateByText',
      failMessage: '劇本生成失敗，稍後嘗試',
      body: {'user_prompt': prompt},
    );

    final dynamic result = data['Result'];

    if (result is! Map) {
      throw Exception('劇本生成失敗，稍後嘗試 ');
    }

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> _resultMap(
    Map<String, dynamic> data,
    String failMessage,
  ) async {
    final dynamic result = data['Result'];

    if (result is! Map) {
      throw Exception(failMessage);
    }

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> drawBadge({
    required String storyId,
  }) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/Badge/Draw',
      failMessage: '抽取徽章失敗',
      body: {'story_id': int.tryParse(storyId) ?? storyId},
    );

    return _resultMap(data, '抽取徽章失敗');
  }

  static Future<Map<String, dynamic>> previewVisitorVlog({
    required String storyId,
  }) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/VisitorVlog/Preview',
      failMessage: '旁白草稿產生失敗',
      body: {'story_id': int.tryParse(storyId) ?? storyId},
    );

    return _resultMap(data, '旁白草稿產生失敗');
  }

  static Future<Map<String, dynamic>> createFinalVisitorVlog({
    required String storyId,
    required String finalScript,
    required String promoCopy,
    required List<String> seoKeywords,
  }) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'POST',
      path: '/api/VisitorVlog/CreateFinal',
      failMessage: '建立 Vlog 失敗',
      body: {
        'story_id': int.tryParse(storyId) ?? storyId,
        'final_script': finalScript,
        'promo_copy': promoCopy,
        'seo_keywords': seoKeywords,
      },
    );

    return _resultMap(data, '建立 Vlog 失敗');
  }

  static Future<Map<String, dynamic>> visitorVlogStatus({
    required String storyId,
    required String taskId,
  }) async {
    final Map<String, dynamic> data = await _storyRequest(
      method: 'GET',
      path:
          '/api/VisitorVlog/Status/${_cleanStoryId(storyId)}'
          '?task_id=${Uri.encodeQueryComponent(taskId)}',
      failMessage: '查詢 Vlog 狀態失敗',
    );

    return _resultMap(data, '查詢 Vlog 狀態失敗');
  }
}
