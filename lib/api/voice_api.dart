import 'dart:io';

/// 語音上傳（前置處理，API 之後補）。
///
/// 流程：「遊你說了算」錄音後，按「開始」會呼叫 [transcribe]，
/// 把錄音檔交給後端轉成文字，拿到文字後自動填進輸入欄，再照原本流程去生成劇本。
///
/// TODO：後端 API 好了以後，只要把下面這個函式補完就好，其他地方都不用改：
///   1. 用 multipart 把 [audio]（m4a / AAC）傳上去（記得帶 AppSession.token）
///   2. 回傳辨識出來的文字
///   3. 失敗就 throw Exception('給使用者看的訊息')
class VoiceApi {
  VoiceApi._();

  /// 目前後端還沒開通，先丟出訊息，畫面會用 AppNotice 顯示
  static Future<String> transcribe(File audio) async {
    throw Exception('語音傳送功能尚未開通，請先改用手動輸入');
  }
}
