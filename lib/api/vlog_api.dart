import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/app_session.dart';

class VlogApi {
  VlogApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl {
    final String value =
        (dotenv.env['API_BASE_URL'] ?? 'https://backend.angelalala.com').trim();

    return value.replaceFirst(RegExp(r'/$'), '');
  }

  Future<Map<String, dynamic>> getStatus({required String storyId}) async {
    final String token = (AppSession.token ?? '').trim();

    if (token.isEmpty) {
      throw Exception('尚未登入，無法取得 Vlog 資料');
    }

    if (storyId.trim().isEmpty) {
      throw Exception('缺少劇本 ID');
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/api/VisitorVlog/Status/${Uri.encodeComponent(storyId)}',
    );

    final http.Response response = await _client
        .get(
          uri,
          headers: {'accept': 'text/plain', 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('查詢 Vlog 失敗（HTTP ${response.statusCode}）');
    }

    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Vlog API 回傳格式錯誤');
    }

    if (decoded['isSuccess'] != true) {
      throw Exception(decoded['message']?.toString() ?? '查詢 Vlog 失敗');
    }

    final dynamic result = decoded['Result'];

    if (result is! Map) {
      throw Exception('找不到 Vlog 資料');
    }

    return Map<String, dynamic>.from(result);
  }

  /// 將影片下載至 App 暫存目錄。

  Future<File> downloadToCache({
    required String storyId,
    required String videoUrl,
  }) async {
    final String normalizedUrl = videoUrl.trim();

    if (normalizedUrl.isEmpty) {
      throw Exception('目前沒有可播放的影片');
    }

    final Uri uri =
        Uri.tryParse(normalizedUrl) ?? (throw Exception('影片網址格式錯誤'));

    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw Exception('不支援的影片網址格式');
    }

    final Directory cacheDirectory = await getTemporaryDirectory();
    final String safeStoryId = storyId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final File cachedFile = File(
      '${cacheDirectory.path}/vlog_story_$safeStoryId.mp4',
    );

    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      return cachedFile;
    }

    final http.Request request = http.Request('GET', uri);
    final http.StreamedResponse response = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('影片下載失敗（HTTP ${response.statusCode}）');
    }

    try {
      await cachedFile.parent.create(recursive: true);

      final IOSink sink = cachedFile.openWrite();
      await response.stream.pipe(sink);

      if (!await cachedFile.exists() || await cachedFile.length() == 0) {
        throw Exception('下載的影片內容是空的');
      }

      return cachedFile;
    } catch (_) {
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
      rethrow;
    }
  }

  /// 將已暫存的影片存入手機相簿。
  Future<void> saveVideoToGallery(File videoFile) async {
    if (!await videoFile.exists() || await videoFile.length() == 0) {
      throw Exception('找不到可儲存的影片檔案');
    }

    bool hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      hasAccess = await Gal.requestAccess();
    }

    if (!hasAccess) {
      throw Exception('沒有相簿權限，無法儲存影片');
    }

    await Gal.putVideo(videoFile.path, album: 'PLAYTAIWAN Vlog');
  }

  void dispose() {
    _client.close();
  }
}
