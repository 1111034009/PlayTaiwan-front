import 'package:flutter/foundation.dart';

//工作階段
class AppSession {
  static final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(
    null,
  );

  static String? get token => tokenNotifier.value;
  static set token(String? v) => tokenNotifier.value = v;

  static String? epId;
  static String? epName;
  static int? store_id;
  static void clear() {
    token = null;
    epId = null;
    epName = null;
    store_id = null;
  }
}
