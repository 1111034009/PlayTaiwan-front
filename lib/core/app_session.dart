class AppSession {
  static String? token;
  static String? epId;
  static String? epName;

  static void clear() {
    token = null;
    epId = null;
    epName = null;
  }
}
