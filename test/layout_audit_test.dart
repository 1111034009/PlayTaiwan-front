// 多語系跑版檢查：每一頁 × 每個語言 × 手機／平板／電腦尺寸，抓出文字太長造成的 overflow。
//
//   flutter test test/layout_audit_test.dart
//
// - 報告寫到 build/layout_audit.txt：哪一頁、哪個語言、哪個尺寸，以及出錯的程式碼位置。
// - API 回應讀 test/fixtures/layout_audit/*.json（檔名見 _fixtureName）；沒有的回 404，
//   用到的網址記在 build/layout_audit_missing.txt。
// - 用真實帳號的資料：AUDIT_FIXTURES=資料夾，裡面分 tourist／merchant／admin 三個子資料夾（依頁面的身分讀），
//   translations.json 放後端真的翻好的句子（沒有的才用假譯文），pages/*.json 放需要參數的頁面資料。
//   真實資料有個人資訊，不要放進 repo。
// - 字型載入 assets/fonts 的正式字型，量出來的字寬才跟手機上一樣。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:playtaiwan/core/app_colors.dart';
import 'package:playtaiwan/core/app_session.dart';
import 'package:playtaiwan/core/app_text_styles.dart';
import 'package:playtaiwan/core/i18n.dart';
import 'package:playtaiwan/core/lang_layout.dart';

import 'layout_audit_pages.dart';

/// 要檢查的尺寸（邏輯像素）：手機小、手機大、平板直、平板橫、電腦
const Map<String, Size> kAuditSizes = {
  '手機 360x740': Size(360, 740),
  '手機 412x915': Size(412, 915),
  '平板 820x1180': Size(820, 1180),
  '平板橫 1180x820': Size(1180, 820),
  '電腦 1440x900': Size(1440, 900),
};

final String? _liveDir = Platform.environment['AUDIT_FIXTURES'];
final String _fixtureDir = _liveDir ?? 'test/fixtures/layout_audit';

/// 目前這一頁用哪個身分（tourist／merchant／admin），真實資料模式依身分讀不同的資料夾
String _role = 'tourist';

/// 後端真的翻好的句子：語言 → 原文 → 譯文
final Map<String, Map<String, String>> _realTranslations = () {
  final file = File('$_fixtureDir/translations.json');
  if (!file.existsSync()) return <String, Map<String, String>>{};
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return raw.map((lang, v) => MapEntry(lang, (v as Map).map((k, t) => MapEntry('$k', '$t'))));
}();

/// 送去翻譯、但還沒有真譯文的句子（語言 → 句子），抓真譯文用
final Map<String, Set<String>> _translateRequests = {};

String _fixtureName(String method, Uri url) {
  final query = url.queryParameters.keys.toList()..sort();
  final q = query.map((k) => '$k=${url.queryParameters[k]}').join('&');
  final raw = '${method}_${url.path}${q.isEmpty ? '' : '_$q'}';
  return raw.replaceAll(RegExp(r'[^A-Za-z0-9_=&.-]+'), '_');
}

final Set<String> _missing = {};

/// 動態內容翻譯（劇本、介紹…）：日文長度跟中文差不多，照原文；英文（韓文也用英文）約是中文字數的 2 倍
String _pseudoTranslate(String text, String lang) {
  if (lang == 'ja') return text;
  const words = ['the', 'quiet', 'temple', 'market', 'street', 'night', 'story', 'secret', 'local', 'journey'];
  var i = 0;
  return text.replaceAllMapped(RegExp(r'[㐀-鿿]+'), (m) {
    final out = StringBuffer();
    while (out.length < m.group(0)!.length * 2) {
      if (out.isNotEmpty) out.write(' ');
      out.write(words[i++ % words.length]);
    }
    return out.toString();
  });
}

Future<http.Response> _fixtureHandler(http.Request request) async {
  if (request.url.path == '/api/Translate') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final texts = (body['texts'] as List).map((t) => t.toString()).toList();
    final lang = body['lang']?.toString() ?? 'en';
    // 韓文的 AI 內容用英文（見 AppLang.contentLang）
    final contentLang = lang == 'ko' ? 'en' : lang;
    String translated(String t) {
      final real = _realTranslations[contentLang]?[t];
      if (real != null) return real;
      _translateRequests.putIfAbsent(contentLang, () => {}).add(t);
      return _pseudoTranslate(t, lang);
    }

    return http.Response(
      jsonEncode({
        'isSuccess': true,
        'Result': {'translations': texts.map(translated).toList()},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  final dir = _liveDir == null ? _fixtureDir : '$_fixtureDir/$_role';
  final exact = File('$dir/${_fixtureName(request.method, request.url)}.json');
  final pathOnly = File('$dir/${_fixtureName(request.method, request.url.replace(query: ''))}.json');
  final file = exact.existsSync() ? exact : (pathOnly.existsSync() ? pathOnly : null);
  if (file == null) {
    _missing.add('$_role ${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');
    return http.Response('{"isSuccess":false,"message":"no fixture"}', 404,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }
  return http.Response.bytes(file.readAsBytesSync(), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final path in files) {
      if (!File(path).existsSync()) continue;
      loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    }
    await loader.load();
  }

  const fonts = 'assets/fonts';
  await load('GenRyuMin2TW', [
    for (final w in ['EL', 'L', 'R', 'M', 'SB', 'B', 'H']) '$fonts/GenRyuMin2TW-$w.otf',
  ]);
  await load('Huninn', ['$fonts/Huninn-Regular.ttf']);
  await load('KaiseiHarunoUmi', [
    for (final w in ['Regular', 'Medium', 'Bold']) '$fonts/KaiseiHarunoUmi-$w.ttf',
  ]);
  // 沒指定字型的地方（Material 預設 Roboto）：用 Segoe UI 代替，字寬接近
  await load('Roboto', [r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\segoeuib.ttf']);
}

class _Overflow {
  _Overflow(this.page, this.lang, this.size, this.message, this.location);
  final String page;
  final String lang;
  final String size;
  final String message;
  final String location;
}

/// 從 FlutterError 的說明裡挑出「哪個 widget、在哪一行」
String _locationOf(FlutterErrorDetails details) {
  final text = details.toString();
  final match = RegExp(r'(?:file:///\S*?/)?(lib/[^\s:]+\.dart):(\d+):(\d+)').firstMatch(text);
  return match == null ? '(找不到位置)' : '${match.group(1)}:${match.group(2)}';
}

/// 文字段落對回程式碼：往上找我們的 Text（i18n.dart 裡面還包了一層 Flutter 的 Text），用它建立的位置；
/// 輸入框提示字（FitHint 裡的 Text）再往上一層，對到用 FitHint 的那一行
String _paragraphLocation(RenderParagraph paragraph) {
  final creator = paragraph.debugCreator;
  if (creator is! DebugCreator) return '(找不到位置)';
  var element = creator.element;
  var depth = 0;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is FitHint) {
      element = ancestor;
      return false;
    }
    if (ancestor.widget is Text && element.widget is! Text) element = ancestor;
    return ++depth < 6;
  });
  final described = debugTransformDebugCreator([DiagnosticsDebugCreator(DebugCreator(element))])
      .map((node) => node.toStringDeep())
      .join('\n');
  final match = RegExp(r'(lib/[^\s:]+\.dart):(\d+):(\d+)').firstMatch(described);
  return match == null ? '(找不到位置)' : '${match.group(1)}:${match.group(2)}';
}

final RegExp _cjk = RegExp(r'[㐀-鿿]');
const String _preview = '簡介預覽截斷';
final RegExp _latin = RegExp(r'[A-Za-z]');

/// 故意不翻的字：語言選單上每個語言用自己的寫法、「語言 Language」中英並列讓外國旅客找得到；
/// 只有一個中文字的（頭像上名字的第一個字、暱稱「aka書」）跟動態翻譯一樣不送，也不算
bool _keepChinese(String text) =>
    AppLang.names.values.contains(text) || text.contains('Language') || text.contains('語言');

/// 不會報錯、但看得出來的問題：文字畫出自己的框外（突出去）、被 maxLines 截成「…」、
/// 英文單字被拆成兩行；英文、韓文畫面上還留著中文（沒翻到）
List<(String, String)> _textIssues(WidgetTester tester, String lang) {
  final issues = <(String, String)>[];
  for (final object in tester.allRenderObjects) {
    if (object is! RenderParagraph || !object.hasSize) continue;
    final text = object.text.toPlainText().replaceAll('\n', ' ').trim();
    if (text.isEmpty) continue;
    final shown = text.length > 24 ? '${text.substring(0, 24)}…' : text;
    final textSize = object.textSize;
    final String issue;
    if (object.didExceedMaxLines && (object.maxLines ?? 0) >= 3) {
      // 三行以上的簡介被截：卡片上的預覽，點進去看全文（中文長一點也一樣會截）
      issue = '$_preview「$shown」';
    } else if (object.didExceedMaxLines) {
      issue = '文字被截斷「$shown」';
    } else if (textSize.width > object.size.width + 1 || textSize.height > object.size.height + 1) {
      final dx = (textSize.width - object.size.width).clamp(0, double.infinity).round();
      final dy = (textSize.height - object.size.height).clamp(0, double.infinity).round();
      issue = '文字超出框 ${dx > 0 ? '寬 ${dx}px ' : ''}${dy > 0 ? '高 ${dy}px ' : ''}「$shown」';
    } else if (_latin.hasMatch(text) && object.getMinIntrinsicWidth(double.infinity) > object.size.width + 1) {
      issue = '單字被拆成兩行「$shown」';
    } else if ((lang == 'en' || lang == 'ko') && _cjk.allMatches(text).length >= 2 && !_keepChinese(text)) {
      issue = '沒翻譯「$shown」';
    } else {
      continue;
    }
    issues.add((issue, _paragraphLocation(object)));
  }
  return issues;
}

String _summaryOf(FlutterErrorDetails details) {
  final text = details.exceptionAsString();
  final match = RegExp(r'A (\w+) overflowed by ([\d.]+) pixels on the (\w+)').firstMatch(text);
  if (match != null) return '${match.group(1)} 超出 ${match.group(2)}px（${match.group(3)}）';
  return text.split('\n').first;
}

Widget _app(Widget page) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: AppLang.locale,
      supportedLocales: AppLang.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.paper,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: TextTheme(
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.bodySmall,
          bodySmall: AppTextStyles.caption,
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.sectionTitle,
          labelLarge: AppTextStyles.button,
          labelMedium: AppTextStyles.label,
        ),
      ),
      home: page,
    );

void main() {
  final pages = auditPages();
  final langFilter = Platform.environment['AUDIT_LANGS']?.split(',');
  final pageFilter = Platform.environment['AUDIT_PAGES']?.split(',');
  final sizeFilter = Platform.environment['AUDIT_SIZES']?.split(',');
  final langs = AppLang.codes.where((c) => langFilter == null || langFilter.contains(c)).toList();
  final results = <_Overflow>[];
  final otherErrors = <String, int>{};

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://fixture.local\nVLOG_API_BASE_URL=http://fixture.local');
    AppSession.token = 'layout-audit';
    await _loadFonts();
  });

  tearDownAll(() {
    final out = StringBuffer();
    final byLocation = <String, List<_Overflow>>{};
    for (final r in results) {
      byLocation.putIfAbsent(r.location, () => []).add(r);
    }
    // 只有外語才出現的排前面（翻譯造成的）；中文也有的是原本就有的問題
    bool chineseToo(String loc) => byLocation[loc]!.any((r) => r.lang == AppLang.zhTW);
    bool previewOnly(String loc) => byLocation[loc]!.every((r) => r.message.startsWith(_preview));
    int rank(String loc) => chineseToo(loc) ? 2 : (previewOnly(loc) ? 1 : 0);
    final locations = byLocation.keys.toList()
      ..sort((a, b) {
        final c = rank(a).compareTo(rank(b));
        return c != 0 ? c : a.compareTo(b);
      });
    out.writeln('多語系跑版檢查：${locations.length} 個位置（${results.length} 次）');
    out.writeln('「中文也有」＝繁體中文也會出現，不是翻譯造成的；「簡介預覽」＝卡片上三行以上的簡介被截，點進去看全文');
    out.writeln();
    for (final loc in locations) {
      final list = byLocation[loc]!;
      final langs = AppLang.codes.where((c) => list.any((r) => r.lang == c)).join(' ');
      final sizes = kAuditSizes.keys.where((s) => list.any((r) => r.size == s)).map((s) => s.split(' ').first).toSet().join('／');
      final note = chineseToo(loc) ? '　（中文也有）' : (previewOnly(loc) ? '　（簡介預覽）' : '');
      out.writeln('■ $loc　[$langs]　$sizes$note');
      final seen = <String>{};
      for (final r in list) {
        final line = '    ${r.page}：${r.message}';
        if (seen.add(line) && seen.length <= 4) out.writeln(line);
      }
    }
    if (otherErrors.isNotEmpty) {
      out.writeln();
      out.writeln('其他錯誤（不是跑版，通常是測試環境沒有的外掛或網路）：');
      for (final e in otherErrors.entries) {
        out.writeln('  ${e.value}×  ${e.key}');
      }
    }
    Directory('build').createSync(recursive: true);
    File('build/layout_audit.txt').writeAsStringSync(out.toString());
    File('build/layout_audit_missing.txt').writeAsStringSync((_missing.toList()..sort()).join('\n'));
    File('build/layout_audit_translate_requests.json').writeAsStringSync(
      jsonEncode(_translateRequests.map((lang, texts) => MapEntry(lang, texts.toList()))),
    );
    // ignore: avoid_print
    print(out.toString().split('\n').take(3).join('\n'));
  });

  for (final entry in pages.entries) {
    if (pageFilter != null && !pageFilter.contains(entry.key)) continue;
    testWidgets('跑版：${entry.key}', (tester) async {
      _role = auditRole(entry.key);
      AppSession.token = _role;
      AppSession.store_id = _role == 'merchant' ? auditStoreId() : null;
      for (final lang in langs) {
        for (final size in kAuditSizes.entries) {
          if (sizeFilter != null && !sizeFilter.any((s) => size.key.contains(s))) continue;
          await AppLang.set(lang);
          tester.view.physicalSize = size.value * 2;
          tester.view.devicePixelRatio = 2;

          void other(Object error) {
            var key = error.toString().split('\n').first;
            if (key.length > 140) key = key.substring(0, 140);
            otherErrors[key] = (otherErrors[key] ?? 0) + 1;
          }

          final original = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.exceptionAsString().contains('overflowed')) {
              results.add(_Overflow(entry.key, lang, size.key, _summaryOf(details), _locationOf(details)));
            } else {
              other(details.exception);
            }
          };
          // 頁面拆掉後才跑的非同步例外（例如新手教學的 Overlay）也在這裡接住，不讓測試框架報錯
          final done = Completer<void>();
          runZonedGuarded(() async {
            try {
              await http.runWithClient(() async {
                await tester.pumpWidget(_app(entry.value()));
                // 新手教學最多等 3 秒才出現，多等一下才看得到教學框
                for (var i = 0; i < 12; i++) {
                  await tester.pump(const Duration(milliseconds: 400));
                }
                for (final (message, location) in _textIssues(tester, lang)) {
                  results.add(_Overflow(entry.key, lang, size.key, message, location));
                }
              }, () => MockClient(_fixtureHandler));
              // 換下一個組合前把頁面拆掉，計時器、動畫一起停
              await tester.pumpWidget(const SizedBox.shrink());
              // 頁面裡較長的計時器（例如地圖 20 秒）也跑完，不然測試框架會報錯
              await tester.pump(const Duration(seconds: 30));
            } catch (e) {
              other('pump 失敗：$e');
            }
            done.complete();
          }, (error, _) => other(error));
          await done.future;
          FlutterError.onError = original;
          // 測試框架記下的例外（非跑版）清掉，不讓整個測試失敗
          while (tester.takeException() != null) {}
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
