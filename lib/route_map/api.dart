import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 地圖頁（lib/route_map）呼叫後端用的。網址用 .env 的 API_BASE_URL、登入的 token 用 AppSession 的，
/// 跟 App 其他頁面一樣。回應格式是 { isSuccess, message, Result }：成功回傳 Result，失敗丟 ApiException(message)。
///
/// lib/route_map 底下其他檔案是從路線展示專案（play_taiwan_demo）原封不動搬過來的，只有這一支是這個 App 自己的：
/// 展示專案那邊有自己的登入頁和後端網址設定，這裡不需要
class Api {
  Api._();
  static final Api instance = Api._();

  /// .env 還沒載入（例如測試）或沒有設定時用本機的後端
  String get baseUrl {
    final value = dotenv.isInitialized ? (dotenv.env['API_BASE_URL'] ?? '').trim() : '';
    return (value.isEmpty ? 'http://localhost:5501' : value).replaceAll(RegExp(r'/+$'), '');
  }

  Future<dynamic> get(String path, [Map<String, Object?>? query]) => _send(() => http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, Object body, {Map<String, Object?>? query}) =>
      _send(() => http.post(_uri(path, query), headers: _headers(), body: jsonEncode(body)));

  Uri _uri(String path, Map<String, Object?>? query) {
    final params = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (AppSession.token != null) 'Authorization': 'Bearer ${AppSession.token}',
      };

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 90));
    } catch (e) {
      throw ApiException('連不到後端（$baseUrl）：$e');
    }

    if (response.statusCode == 401) throw ApiException('登入已過期，請重新登入');

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('後端回應格式錯誤（HTTP ${response.statusCode}）');
    }

    if (data['isSuccess'] != true) {
      throw ApiException(data['message'] as String? ?? '發生錯誤（HTTP ${response.statusCode}）');
    }
    return data['Result'];
  }
}
