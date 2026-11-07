// 多語系：語言設定、介面翻譯、取代 Flutter 的 Text。
//
// 原本的程式照舊寫中文（const Text('出發探險') 不用改），畫面要顯示時才查表翻譯：
// - 各檔案 import material.dart 時 hide Text，改用這裡的 Text（參數跟 Flutter 的一樣，也能 const）。
// - 字串直接交給 Flutter 顯示的地方（hintText、tooltip…）包一層 trs()。
// - 程式裡比對用的中文（例如 status == '已完成'）完全不受影響。
// 繁體中文時一律回原文。切換語言時整個畫面重畫一次。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import 'lang_layout.dart';

export 'lang_layout.dart' show LangLayout;

class AppLang {
  AppLang._();

  /// 預設繁體中文；台語、客語只有介面文字，語音與 AI 生成內容維持華語
  static const String zhTW = 'zh-TW';
  static const List<String> codes = [zhTW, 'en', 'ja', 'ko', 'nan', 'hak'];

  /// 選單上每個語言用它自己的寫法
  static const Map<String, String> names = {
    zhTW: '繁體中文',
    'en': 'English',
    'ja': '日本語',
    'ko': '한국어',
    'nan': '台語（Tâi-gí）',
    'hak': '客語（Hak-fa）',
  };

  static const String _prefKey = 'app_lang_v1';

  static final ValueNotifier<String> current = ValueNotifier(zhTW);

  static String get code => current.value;
  static bool get isChinese => current.value == zhTW;

  /// 給 MaterialApp：台語、客語用繁體中文的系統元件（日期選擇器等）
  static Locale get locale => switch (current.value) {
    'en' => const Locale('en', 'US'),
    'ja' => const Locale('ja', 'JP'),
    'ko' => const Locale('ko', 'KR'),
    _ => const Locale('zh', 'TW'),
  };

  static const List<Locale> supportedLocales = [
    Locale('zh', 'TW'),
    Locale('en', 'US'),
    Locale('ja', 'JP'),
    Locale('ko', 'KR'),
  ];

  /// 給後端／AI 的內容語言（語音、劇本與介紹翻譯）：台語、客語維持華語
  static String get contentLang => switch (current.value) {
    'en' || 'ja' || 'ko' => current.value,
    _ => zhTW,
  };

  /// 表格裡每個語言的欄位（strings.dart 每列依序是 en, ja, ko, nan, hak）
  static int get _column => switch (current.value) {
    'en' => 0,
    'ja' => 1,
    'ko' => 2,
    'nan' => 3,
    'hak' => 4,
    _ => -1,
  };

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && codes.contains(saved)) current.value = saved;
    } catch (_) {}
  }

  static Future<void> set(String code) async {
    if (!codes.contains(code) || code == current.value) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
    _cache.clear();
    current.value = code;
    rebuildAll();
  }

  /// 整個畫面重畫一次：const 的 Text、已經算好的 hintText 都會重新翻譯
  static void rebuildAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element element) {
        element.markNeedsBuild();
        element.visitChildren(mark);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(mark);
    });
    // 畫面靜止時不會有下一個畫格，上面的 callback 就不會跑（動態翻譯回來時就是這樣）
    WidgetsBinding.instance.scheduleFrame();
  }

  static final Map<String, String> _cache = {};
}

final RegExp _cjk = RegExp(r'[㐀-鿿]');
final RegExp _placeholder = RegExp(r'\{(\d+)\}');

/// 有 {0} {1} 的字串：編成正規表示式，依固定文字長度排序（越具體的越先比）
class _Template {
  _Template(this.key, this.anchor, this.pattern, this.order, this.fixedLength);
  final String key;
  final String anchor;
  final RegExp pattern;

  /// 固定文字總長：越長越具體，先比（「可查詢 {0} 個景點」要排在「{0} 個景點」前面）
  final int fixedLength;

  /// 第 n 個擷取群組對應的 {編號}
  final List<int> order;
}

List<_Template>? _templates;

List<_Template> _compileTemplates() {
  final list = <_Template>[];
  for (final key in kStrings.keys) {
    if (!key.contains('{')) continue;
    final pieces = key.split(_placeholder);
    if (!pieces.any(_cjk.hasMatch)) continue;
    final anchor = pieces.reduce((a, b) => a.length >= b.length ? a : b);
    final buffer = StringBuffer('^');
    final order = <int>[];
    var last = 0;
    for (final match in _placeholder.allMatches(key)) {
      buffer.write(RegExp.escape(key.substring(last, match.start)));
      buffer.write('(.*?)');
      order.add(int.parse(match.group(1)!));
      last = match.end;
    }
    buffer.write(RegExp.escape(key.substring(last)));
    buffer.write(r'$');
    final fixed = pieces.fold<int>(0, (sum, piece) => sum + piece.length);
    list.add(
      _Template(
        key,
        anchor,
        RegExp(buffer.toString(), dotAll: true),
        order,
        fixed,
      ),
    );
  }
  list.sort((a, b) => b.fixedLength.compareTo(a.fixedLength));
  return list;
}

String? _matchTemplate(String text) {
  _templates ??= _compileTemplates();
  for (final t in _templates!) {
    if (!text.contains(t.anchor)) continue;
    final match = t.pattern.firstMatch(text);
    if (match == null) continue;
    final target = _lookup(t.key);
    if (target == null) return null;
    final args = List<Object?>.filled(
      t.order.fold(0, (a, b) => b + 1 > a ? b + 1 : a),
      '',
    );
    for (var g = 0; g < t.order.length; g++) {
      args[t.order[g]] = translate(match.group(g + 1) ?? '');
    }
    return _fill(target, args);
  }
  return null;
}

String? _lookup(String zh) {
  final row = kStrings[zh];
  if (row == null) return null;
  final column = AppLang._column;
  if (column < 0 || column >= row.length) return null;
  final value = row[column];
  return value.isEmpty ? null : value;
}

String _fill(String template, List<Object?> args) =>
    template.replaceAllMapped(_placeholder, (m) {
      final i = int.parse(m.group(1)!);
      return i < args.length ? '${args[i] ?? ''}' : m.group(0)!;
    });

/// 編號、選項代號、hashtag 開頭的字（「1. 芎林之巖」「A.康熙」「#火雞肉飯」）：前綴照留，只翻後面
final RegExp _prefixed = RegExp(r'^(#|\d+[.、．]\s*|[A-Z][.．]\s*)(.*[㐀-鿿].*)$');

final RegExp _strongSeparator = RegExp('[・｜　]');
final RegExp _weakSeparator = RegExp('[、，,]| ');

/// 幾段串起來的字，整串查不到時一段一段翻（回傳譯文，以及是不是每一段都翻好了）：
/// - 用 ・ ｜ 全形空白 串的（「餐廳・其他」「店名｜優惠」「#588　臺中市・北區」「週三　11:00–21:00」）：
///   每一段各自翻，表裡沒有的那段交給動態翻譯（翻好前先顯示原文）。整串送 AI 的話，地名、店名常被亂翻。
/// - 用逗號、頓號、半形空白串的（「臺中市 西區」「島嶼城市,午夜台灣」）：每一段都在表裡才拆，
///   不然多半是一句話，整句翻比較通順。
(String, bool)? _translateJoined(String text) {
  final bool ja = AppLang.code == 'ja';
  if (_strongSeparator.hasMatch(text)) {
    final StringBuffer out = StringBuffer();
    var complete = true;
    var last = 0;
    void addPart(String part) {
      final String p = part.trim();
      if (p.isEmpty || !_cjk.hasMatch(p)) {
        out.write(p);
        return;
      }
      final String t = translate(p);
      if (t == p && DynamicTranslator.isPending(p)) complete = false;
      out.write(t);
    }

    for (final Match m in _strongSeparator.allMatches(text)) {
      addPart(text.substring(last, m.start));
      out.write(switch (m[0]) {
        '・' => ja ? '・' : ' · ',
        '｜' => ja ? '｜' : ' | ',
        _ => ja ? '　' : ' ',
      });
      last = m.end;
    }
    addPart(text.substring(last));
    return (out.toString(), complete);
  }

  if (_weakSeparator.hasMatch(text)) {
    final List<String> parts = text.split(_weakSeparator);
    final List<String> out = [];
    for (final String part in parts) {
      final String p = part.trim();
      if (p.isEmpty) continue;
      if (!_cjk.hasMatch(p)) {
        out.add(p);
        continue;
      }
      final String? t = _lookup(p) ?? _matchTemplate(p);
      if (t == null) return null;
      out.add(t);
    }
    final bool spaced = !RegExp('[、，,]').hasMatch(text);
    return (out.join(spaced ? ' ' : (ja ? '、' : ', ')), true);
  }
  return null;
}

/// 已經是譯文的字（表裡目前語言那一欄、動態翻譯的結果）：顯示時又被包一次 Text 也不再送去翻
/// （例如日文的「パスワードを入力」被當成新的中文句子送給 AI，又被改成別的說法）
Set<String> _outputs = {};
String? _outputsLang;

bool _isTranslation(String text) {
  if (_outputsLang != AppLang.code) {
    final int column = AppLang._column;
    _outputs = {
      for (final List<String> row in kStrings.values)
        if (column >= 0 && column < row.length && row[column].isNotEmpty)
          row[column],
    };
    _outputsLang = AppLang.code;
  }
  return _outputs.contains(text) || DynamicTranslator.isResult(text);
}

/// 依目前語言翻譯一段要顯示的文字（整句、樣板、逐行），查不到就回原文
String translate(String text) {
  if (AppLang.isChinese || text.isEmpty || !_cjk.hasMatch(text)) return text;
  final cached = AppLang._cache[text];
  if (cached != null) return cached;

  final trimmed = text.trim();
  String result;
  // 表裡查到、套樣板、拆段或去前綴後已經各自翻過（翻不了的段落也是）：整串不再送動態翻譯。
  // 日文譯文常跟原文一樣（「新北市」「未使用 {0}」），不能拿「譯文＝原文」當作沒查到，
  // 不然又整句送 AI，回來的「未使用」把數字蓋掉
  var handled = true;
  if (trimmed != text) {
    // 前後空白照留，只翻中間
    result = text.replaceFirst(trimmed, translate(trimmed));
    handled = false;
  } else if (text.startsWith('Exception: ')) {
    result = translate(text.substring(11));
    handled = false;
  } else if (_lookup(text) case final String hit) {
    result = hit;
  } else if (_isTranslation(text)) {
    // 已經是譯文（日文常有漢字，「近くの観光スポット・名所を探す」）：原樣顯示，也不拆段
    result = text;
  } else {
    String? found =
        (text.contains('\n')
            ? text.split('\n').map(translate).join('\n')
            : null) ??
        _matchTemplate(text);
    final Match? prefixed = found == null ? _prefixed.firstMatch(text) : null;
    if (prefixed != null) {
      final String rest = prefixed[2]!;
      final String t = translate(rest);
      if (t == rest && DynamicTranslator.isPending(rest)) return text;
      found = prefixed[1]! + t;
    }
    if (found == null) {
      final (String, bool)? joined = _translateJoined(text);
      // 有一段還在等動態翻譯：先顯示，翻好後會重畫，這次不寫進快取
      if (joined != null && !joined.$2) return joined.$1;
      found = joined?.$1;
    }
    result = found ?? text;
    handled = found != null;
  }

  // 介面表裡沒有的中文（劇本、NPC 台詞、景點介紹…）：英、日文交給後端翻（韓文用英文），回來前先顯示原文
  // 多行的已經逐行送過，不再整段送
  if (result == text &&
      !handled &&
      AppLang.contentLang != AppLang.zhTW &&
      !text.contains('\n')) {
    final dynamicResult = DynamicTranslator.lookup(text);
    if (dynamicResult != null) {
      result = dynamicResult;
    } else {
      DynamicTranslator.request(text);
      return text; // 翻好後會重畫，這次不寫進快取
    }
  }

  if (AppLang._cache.length > 4000) AppLang._cache.clear();
  AppLang._cache[text] = result;
  return result;
}

/// 後端翻譯動態內容（POST /api/Translate，後端有快取、同一句只翻一次）。
/// 畫面要顯示時排隊，0.3 秒內的湊成一批送出；翻好後整個畫面重畫一次。
/// 翻不了（AI 還沒更新、連不上）的句子 2 分鐘內不再送，先顯示原文。
class DynamicTranslator {
  DynamicTranslator._();

  static const int _batchSize = 40;
  static const int _maxLength = 3000;
  static const Duration _retryAfter = Duration(minutes: 2);

  /// 內容語言（en、ja）→ 原文 → 譯文
  static final Map<String, Map<String, String>> _done = {};
  static final Map<String, DateTime> _failed = {};
  static final Set<String> _pending = {};
  static final Set<String> _inFlight = {};

  /// 內容語言 → 翻好的譯文（認得出「這已經是譯文」）
  static final Map<String, Set<String>> _results = {};
  static Timer? _timer;
  static bool _sending = false;

  static String? lookup(String text) =>
      _done[AppLang.contentLang]?[text.trim()];

  /// 還在排隊或翻譯中
  static bool isPending(String text) =>
      _pending.contains(text.trim()) || _inFlight.contains(text.trim());

  /// 這段字本身就是動態翻譯的結果
  static bool isResult(String text) =>
      _results[AppLang.contentLang]?.contains(text) ?? false;

  /// 少於 2 個中文字的不送（單字多半是圖表標籤、縮寫）。
  /// 短的劇本標題、關卡代號、優惠券名稱、店名也要翻（外國旅客看不懂中文）：
  /// AI 那邊的規則是地名用官方英文或拼音、小吃保留原名再加說明
  /// 地址也送：AI 那邊用規則轉成郵局英譯格式（No. 100, Sec. 3, Sanmin Rd., North District, Taichung City），
  /// 不經過模型；日文原樣回傳。導航、複製用的還是資料裡的中文地址
  static bool worthTranslating(String key) => _cjk.allMatches(key).length >= 2;

  static void request(String text) {
    final key = text.trim();
    if (key.isEmpty || key.length > _maxLength || !worthTranslating(key))
      return;
    final failedAt = _failed['${AppLang.contentLang}|$key'];
    if (failedAt != null && DateTime.now().difference(failedAt) < _retryAfter)
      return;
    if (!_pending.add(key)) return;
    _timer ??= Timer(const Duration(milliseconds: 300), _flush);
  }

  static Future<void> _flush() async {
    _timer = null;
    if (_sending || _pending.isEmpty) return;
    _sending = true;
    final lang = AppLang.code;
    final contentLang = AppLang.contentLang;
    final batch = _pending.take(_batchSize).toList();
    _pending.removeAll(batch);
    _inFlight.addAll(batch);
    var changed = false;
    try {
      final base = (dotenv.env['API_BASE_URL'] ?? '').trim().replaceFirst(
        RegExp(r'/$'),
        '',
      );
      final response = await http
          .post(
            Uri.parse('$base/api/Translate'),
            headers: {
              'Content-Type': 'application/json',
              'accept': 'application/json',
            },
            body: jsonEncode({'lang': lang, 'texts': batch}),
          )
          .timeout(const Duration(minutes: 3));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final result = (body is Map) ? body['Result'] : null;
      final list = (result is Map) ? result['translations'] : null;
      if (response.statusCode == 200 &&
          list is List &&
          list.length == batch.length) {
        final done = _done.putIfAbsent(contentLang, () => {});
        final results = _results.putIfAbsent(contentLang, () => {});
        for (var i = 0; i < batch.length; i++) {
          final value = list[i]?.toString() ?? batch[i];
          if (value == batch[i]) {
            _failed['$contentLang|${batch[i]}'] = DateTime.now();
          } else {
            done[batch[i]] = value;
            results.add(value);
            changed = true;
          }
        }
      } else {
        for (final key in batch) {
          _failed['$contentLang|$key'] = DateTime.now();
        }
      }
    } catch (_) {
      for (final key in batch) {
        _failed['$contentLang|$key'] = DateTime.now();
      }
    } finally {
      _sending = false;
      _inFlight.removeAll(batch);
    }
    // 翻的時候使用者換了語言：這批照樣留著，不用重畫
    if (changed && AppLang.contentLang == contentLang) {
      AppLang._cache.clear();
      AppLang.rebuildAll();
    }
    if (_pending.isNotEmpty)
      _timer ??= Timer(const Duration(milliseconds: 300), _flush);
  }
}

/// 程式裡組字串用：tr('查無「{0}」', [query])。key 用繁體中文原文
String tr(String zh, [List<Object?> args = const []]) {
  final target = AppLang.isChinese ? null : _lookup(zh);
  return _fill(target ?? zh, args);
}

/// 縣市、行政區下拉選單用的短名稱：選單本來就在選地區，英文省掉 County／City／District／Township
/// （New Taipei City → New Taipei、Beitou District → Beitou），窄的選單才放得下
String trArea(String zh) {
  final String name = translate(zh);
  if (AppLang.code != 'en') return name;
  // Lienchiang (Matsu) → Matsu：外國旅客比較熟的叫法
  final Match? alias = RegExp(r'^.+ \((.+)\)$').firstMatch(name);
  if (alias != null) return alias.group(1)!;
  final String short = name.replaceFirst(
    RegExp(r' (County|City|District|Township)$'),
    '',
  );
  // 新竹、嘉義的縣和市只差在後面那個字：縣寫成 Co. 才分得出來
  if (short == 'Hsinchu' || short == 'Chiayi')
    return name.replaceFirst(' County', ' Co.');
  return short;
}

/// 表單驗證：錯誤訊息是 Flutter 輸入框自己畫的，不會經過這裡的 Text，先翻好再交出去。
/// 用法：TextFormField(validator: trValidator(_validateName))
FormFieldValidator<String>? trValidator(
  FormFieldValidator<String>? validator,
) => validator == null ? null : (String? value) => trs(validator(value));

/// 包在 hintText、tooltip 這類直接交給 Flutter 顯示的字串外面；可為 null
T trs<T extends String?>(T text) =>
    (text == null ? null : translate(text)) as T;

/// 翻譯 TextSpan 樹裡的每段文字
InlineSpan trSpan(InlineSpan span) {
  if (AppLang.isChinese || span is! TextSpan) return span;
  return TextSpan(
    text: span.text == null ? null : translate(span.text!),
    children: span.children?.map(trSpan).toList(),
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

/// 套件規定要 Flutter 原本的 Text 型別時用（字串自己先 trs()）
typedef FlutterText = m.Text;

/// 取代 Flutter 的 Text：參數一樣、可以 const，顯示時才翻譯
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// 外語比中文長、放不下時先縮字（見 lang_layout.dart）；繁體中文原樣
  @override
  Widget build(BuildContext context) => shrinkWhenNeeded(context, _text());

  Widget _text() {
    if (textSpan != null) {
      return m.Text.rich(
        trSpan(textSpan!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: trs(semanticsLabel),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text(
      translate(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: trs(semanticsLabel),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

/// 語言選單（設定、登入頁共用）
Future<void> showLanguagePicker(BuildContext context) async {
  final picked = await m.showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      // 矮螢幕（登入頁、橫向）選項放不下時可以捲動，不會底部溢位
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '語言 Language',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            for (final code in AppLang.codes)
              m.ListTile(
                leading: m.Icon(
                  code == AppLang.code
                      ? m.Icons.radio_button_checked
                      : m.Icons.radio_button_unchecked,
                ),
                // 語言名稱一律用它自己的寫法，不翻譯
                title: m.Text(AppLang.names[code]!),
                subtitle: code == 'nan' || code == 'hak'
                    ? const Text('介面文字；語音與 AI 內容維持華語')
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(code),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (picked != null) await AppLang.set(picked);
}
