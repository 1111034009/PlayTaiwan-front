import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';

class AdminPage {
  const AdminPage(this.items, this.total);
  final List<Map<String, dynamic>> items;
  final int total;
}

class AdminApi {
  AdminApi._();

  static String get _base {
    final v = dotenv.isInitialized
        ? (dotenv.env['API_BASE_URL'] ?? '').trim()
        : '';
    return (v.isEmpty ? 'https://backend.angelalala.com' : v).replaceAll(
      RegExp(r'/+$'),
      '',
    );
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (AppSession.token != null) 'Authorization': 'Bearer ${AppSession.token}',
  };

  static Uri _uri(String path, [Map<String, Object?>? query]) {
    final q = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return Uri.parse(
      '$_base$path',
    ).replace(queryParameters: q.isEmpty ? null : q);
  }

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response r;
    try {
      r = await request().timeout(const Duration(seconds: 60));
    } catch (e) {
      throw Exception('連不到後端：$e');
    }
    if (r.statusCode == 401) throw Exception('登入已過期，請重新登入');
    if (r.statusCode == 403) throw Exception('沒有管理員權限');
    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('後端回應格式錯誤（HTTP ${r.statusCode}）');
    }
    if (data['isSuccess'] != true) {
      throw Exception(data['message'] ?? '發生錯誤（HTTP ${r.statusCode}）');
    }
    return data['Result'];
  }

  static Future<dynamic> _get(String p, [Map<String, Object?>? q]) =>
      _send(() => http.get(_uri(p, q), headers: _headers));

  static Future<dynamic> _post(String p, Object b) =>
      _send(() => http.post(_uri(p), headers: _headers, body: jsonEncode(b)));

  static Future<dynamic> _put(String p, Object b) =>
      _send(() => http.put(_uri(p), headers: _headers, body: jsonEncode(b)));

  static Future<dynamic> _delete(String p) =>
      _send(() => http.delete(_uri(p), headers: _headers));

  static Map<String, dynamic> _map(dynamic r) =>
      Map<String, dynamic>.from(r as Map);

  static AdminPage _page(dynamic r) {
    final m = r as Map<String, dynamic>;
    final list = (m['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return AdminPage(list, (m['total'] as num?)?.toInt() ?? list.length);
  }

  static Future<void> logout() => _post('/api/Auth/Logout', {});

  static Future<Map<String, dynamic>> profile() async =>
      _map(await _get('/api/Auth/Profile'));

  static Future<void> updateProfile(String name) =>
      _post('/api/Auth/Profile', {'auth_name': name});

  static Future<void> changePassword(String oldPassword, String newPassword) =>
      _post('/api/Auth/ChangePassword', {
        'OldPassword': oldPassword,
        'NewPassword': newPassword,
      });

  static Future<AdminPage> users({
    String? keyword,
    int? authType,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async => _page(
    await _get('/api/Admin/Users', {
      'keyword': keyword,
      'auth_type': authType,
      'is_active': isActive,
      'page': page,
      'page_size': pageSize,
    }),
  );

  static Future<Map<String, dynamic>> getUser(int id) async =>
      _map(await _get('/api/Admin/Users/$id'));

  static Future<void> createUser(Map<String, dynamic> body) =>
      _post('/api/Admin/Users', body);

  static Future<void> updateUser(int id, Map<String, dynamic> body) =>
      _put('/api/Admin/Users/$id', body);

  static Future<void> deleteUser(int id) => _delete('/api/Admin/Users/$id');

  static Future<AdminPage> stories({
    String? keyword,
    int? auId,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async => _page(
    await _get('/api/Admin/Stories', {
      'keyword': keyword,
      'au_id': auId,
      'is_active': isActive,
      'page': page,
      'page_size': pageSize,
    }),
  );

  static Future<Map<String, dynamic>> getStory(int id) async =>
      _map(await _get('/api/Admin/Stories/$id'));

  static Future<void> createStory(Map<String, dynamic> body) =>
      _post('/api/Admin/Stories', body);

  static Future<void> updateStory(int id, Map<String, dynamic> body) =>
      _put('/api/Admin/Stories/$id', body);

  static Future<void> deleteStory(int id) => _delete('/api/Admin/Stories/$id');

  static Future<List<String>> badgeCategories() async {
    final r = await _get('/api/Admin/Badges/Categories');
    return (r as List? ?? []).map((e) => '$e').toList();
  }

  static Future<AdminPage> badges({
    String? keyword,
    String? category,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async => _page(
    await _get('/api/Admin/Badges', {
      'keyword': keyword,
      'b_fication': category,
      'is_active': isActive,
      'page': page,
      'page_size': pageSize,
    }),
  );

  static Future<Map<String, dynamic>> getBadge(int id) async =>
      _map(await _get('/api/Admin/Badges/$id'));

  static Future<void> createBadge(Map<String, dynamic> body) =>
      _post('/api/Admin/Badges', body);

  static Future<void> updateBadge(int id, Map<String, dynamic> body) =>
      _put('/api/Admin/Badges/$id', body);

  static Future<void> deleteBadge(int id) => _delete('/api/Admin/Badges/$id');

  static Future<String> upload(String filename, List<int> bytes) async {
    final r = await _send(() async {
      final req = http.MultipartRequest('POST', _uri('/api/Upload'))
        ..headers.addAll({
          if (AppSession.token != null)
            'Authorization': 'Bearer ${AppSession.token}',
        })
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      return http.Response.fromStream(await req.send());
    });
    return r as String;
  }
}
