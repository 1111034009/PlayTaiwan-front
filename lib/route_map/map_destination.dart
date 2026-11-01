import 'models.dart';

/// 「要去的地點」記在這裡（例如小幫手推薦的地點），切到別的分頁再回到地圖還會在。
///
/// - 沒有劇本：地圖頁顯示「我的位置 → 這個地點」
/// - 有劇本：劇本的藏寶圖 + 這個地點的順路
/// - 使用者按掉（關閉／結束順路）、登出或換新的地點才會改變
class MapDestination {
  MapDestination._();

  static PlacePoint? current;

  static void clear() => current = null;
}
