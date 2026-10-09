class AppSession {
  static String? token;
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
