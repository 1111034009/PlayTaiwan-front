import 'package:flutter/foundation.dart';

// 工作階段
class AppSession {
  static final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(
    null,
  );

  static String? get token => tokenNotifier.value;
  static set token(String? v) => tokenNotifier.value = v;

  static String? epId;
  static String? epName;
  static int? store_id;
  // 店家資料
  static final ValueNotifier<Map<String, dynamic>?> merchantProfileNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Map<String, dynamic>? get merchantProfile =>
      merchantProfileNotifier.value;

  static set merchantProfile(Map<String, dynamic>? value) {
    merchantProfileNotifier.value = value;
  }

  static void updateMerchantProfile(Map<String, dynamic> data) {
    merchantProfile = {...?merchantProfile, ...data};
  }

  static void clear() {
    token = null;
    epId = null;
    epName = null;
    store_id = null;
    merchantProfile = null;
  }
}
