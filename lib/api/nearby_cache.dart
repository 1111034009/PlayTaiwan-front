import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/app_session.dart';

class NearbyCache {
  NearbyCache._();

  static final NearbyCache instance = NearbyCache._();

  static const double radiusKm = 2.5;

  Timer? _timer;

  List<NearbyPlaceData> _places = [];

  List<NearbyPlaceData> get places => List.unmodifiable(_places);

  DateTime? _lastUpdated;

  DateTime? get lastUpdated => _lastUpdated;

  bool get hasData => _places.isNotEmpty;

  // ============================================================
  // 登入成功後呼叫
  // ============================================================

  void start() {
    if (_timer != null) {
      return;
    }

    // 登入後立即背景預抓
    refresh().catchError((error) {
      debugPrint('Nearby background refresh error: $error');
    });

    // 每 10 分鐘重新抓
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      refresh().catchError((error) {
        debugPrint('Nearby periodic refresh error: $error');
      });
    });
  }

  // ============================================================
  // 登出時呼叫
  // ============================================================

  void stop() {
    _timer?.cancel();
    _timer = null;

    _places = [];
    _lastUpdated = null;
  }

  // ============================================================
  // 重新取得附近景點
  // ============================================================

  Future<List<NearbyPlaceData>> refresh() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('請開啟手機的位置服務');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception('使用附近景點功能需要位置權限');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('位置權限已永久拒絕，請到手機設定開啟位置權限');
    }

    // ==========================================================
    // 每次 refresh 都重新取得 GPS
    // ==========================================================

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final lat = position.latitude;
    final lng = position.longitude;

    debugPrint('Nearby refresh GPS: lat=$lat, lng=$lng');

    final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';

    final uri = Uri.parse(
      '$apiBaseUrl/api/Story/NearbyAttractions'
      '?lat=$lat'
      '&lng=$lng'
      '&radiusKm=$radiusKm',
    );

    final token = AppSession.token;

    if (token == null || token.isEmpty) {
      throw Exception('尚未登入，無法取得附近景點');
    }

    final response = await http.get(
      uri,
      headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
    );

    debugPrint('Nearby API Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('附近景點 API 錯誤：${response.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['isSuccess'] != true) {
      throw Exception(data['message']?.toString() ?? '附近景點查詢失敗');
    }

    final List<dynamic> result = data['Result'] as List<dynamic>? ?? [];

    final List<NearbyPlaceData> loadedPlaces = [];

    for (final item in result) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final name = item['name']?.toString() ?? '未知景點';

      final placeLat = _toDouble(item['lat']);
      final placeLon = _toDouble(item['lon']);
      final distanceM = _toDouble(item['distance_m']);

      if (placeLat == null || placeLon == null) {
        continue;
      }

      loadedPlaces.add(
        NearbyPlaceData(
          title: name,
          lat: placeLat,
          lon: placeLon,
          distanceM: distanceM ?? 0,
        ),
      );
    }

    loadedPlaces.sort((a, b) => a.distanceM.compareTo(b.distanceM));

    // ==========================================================
    // API 成功後才更新 cache
    //
    // API 失敗時保留舊資料
    // ==========================================================

    _places = loadedPlaces;
    _lastUpdated = DateTime.now();

    debugPrint('Nearby cache updated: ${loadedPlaces.length} places');

    return List.unmodifiable(_places);
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}

// ================================================================
// Cache 使用的資料 Model
// ================================================================

class NearbyPlaceData {
  final String title;
  final double lat;
  final double lon;
  final double distanceM;

  const NearbyPlaceData({
    required this.title,
    required this.lat,
    required this.lon,
    required this.distanceM,
  });
}
