import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../route_map/models.dart' show PlacePoint;
import 'story_route_map_page.dart';
import '../api/nearby_cache.dart';
import '../api/story_api.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

const String _kNpcAvatarAsset = 'img/talk_cat.png';

/// 對話訊息的發送者
enum _Sender { npc, user, system }

class _Entry {
  final _Sender sender;
  final Widget child;
  const _Entry(this.sender, this.child);
}

class _ChoiceOption {
  final IconData icon;
  final String label;
  const _ChoiceOption({required this.icon, required this.label});
}

class AiTalkPage extends StatefulWidget {
  const AiTalkPage({super.key});

  @override
  State<AiTalkPage> createState() => _AiTalkPageState();
}

class _AiTalkPageState extends State<AiTalkPage> {
  static const String _npcName = '小精靈';
  static const String _npcSubtitle = '探員隨身尋找';
  static const String _questLabel = '找個隨機地點';
  static const String _questDefaultText = '我想找個附近好玩的地方';
  static const String _busyText = '正在對話中，請等待生成';
  static const String _cacheKey = 'ai_talk_history_v1';
  static const Duration _cacheLife = Duration(minutes: 10);

  static const List<String> _foodKeywords = [
    '餐',
    '麵',
    '飯',
    '食',
    '小吃',
    '咖啡',
    'cafe',
    'coffee',
    '茶',
    '飲',
    '冰',
    '甜',
    '餅',
    '糕',
    '麥',
    '火鍋',
    '燒',
    '烤',
    '酒',
    '廚',
    '鍋',
    '粥',
    '滷',
    '肉',
    '雞',
    '魚',
    '牛',
    '豬',
    '豆花',
    '便當',
    '早餐',
    '宵夜',
  ];

  final List<_Entry> _entries = [];
  final List<Map<String, dynamic>> _records = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final math.Random _random = math.Random();

  List<NearbyPlaceData> _pool = [];
  int _poolIndex = 0;
  bool _busy = false;
  _Entry? _typing;

  bool _isFood(NearbyPlaceData place) {
    final String name = place.title.toLowerCase();

    return _foodKeywords.any((keyword) => name.contains(keyword));
  }

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String raw = prefs.getString(_cacheKey) ?? '';

      if (raw.isNotEmpty) {
        final dynamic list = jsonDecode(raw);
        final int oldest = DateTime.now()
            .subtract(_cacheLife)
            .millisecondsSinceEpoch;

        if (list is List) {
          for (final dynamic item in list) {
            if (item is! Map) continue;

            final Map<String, dynamic> record = Map<String, dynamic>.from(item);
            final int ts = (record['ts'] as num?)?.toInt() ?? 0;

            if (ts < oldest) continue;

            final Widget? built = _widgetFor(record);

            if (built == null) continue;

            _records.add(record);
            _entries.add(
              _Entry(record['t'] == 'user' ? _Sender.user : _Sender.npc, built),
            );
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    if (_records.isEmpty) {
      _npcText('探員閣下您好，今日想找我做點甚麼呢?');
    } else {
      setState(() {});
      _scrollToBottom();
    }

    _showMainMenu();
    _save();
  }

  Widget? _widgetFor(Map<String, dynamic> record) {
    final dynamic type = record['t'];

    if (type == 'npc') {
      return _NpcBubble(child: Text('${record['text']}', style: _npcTextStyle));
    }

    if (type == 'user') {
      return _UserBubble(
        child: Text('${record['text']}', style: _userTextStyle),
      );
    }

    if (type == 'spin' && record['data'] is Map) {
      return _SpinResultCard(
        data: Map<String, dynamic>.from(record['data'] as Map),
      );
    }

    if (type == 'nearby' && record['places'] is List) {
      final List<NearbyPlaceData> places = (record['places'] as List)
          .whereType<Map>()
          .map(
            (p) => NearbyPlaceData(
              title: '${p['title']}',
              lat: (p['lat'] as num).toDouble(),
              lon: (p['lon'] as num).toDouble(),
              distanceM: (p['d'] as num).toDouble(),
            ),
          )
          .toList();

      return places.isEmpty ? null : _NearbyListCard(places: places);
    }

    return null;
  }

  void _remember(Map<String, dynamic> record) {
    _records.add({...record, 'ts': DateTime.now().millisecondsSinceEpoch});
    _save();
  }

  Future<void> _save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString(_cacheKey, jsonEncode(_records));
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _addEntry(_Sender sender, Widget child, {Map<String, dynamic>? record}) {
    setState(() => _entries.add(_Entry(sender, child)));

    if (record != null) {
      _remember(record);
    }

    _scrollToBottom();
  }

  void _showTyping() {
    final _Entry entry = _Entry(_Sender.npc, const _TypingBubble());

    _typing = entry;

    setState(() => _entries.add(entry));
    _scrollToBottom();
  }

  void _hideTyping() {
    final _Entry? entry = _typing;

    if (entry == null) return;

    _typing = null;

    if (mounted) {
      setState(() => _entries.remove(entry));
    }
  }

  bool _guardBusy() {
    if (!_busy) return false;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_busyText)));

    return true;
  }

  void _npcText(String text) {
    _addEntry(
      _Sender.npc,
      _NpcBubble(child: Text(text, style: _npcTextStyle)),
      record: {'t': 'npc', 'text': text},
    );
  }

  void _userText(String text) {
    _addEntry(
      _Sender.user,
      _UserBubble(child: Text(text, style: _userTextStyle)),
      record: {'t': 'user', 'text': text},
    );
  }

  TextStyle get _npcTextStyle =>
      AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.4);

  TextStyle get _userTextStyle =>
      AppTextStyles.body.copyWith(color: AppColors.paper, height: 1.4);

  Future<void> _delay([int ms = 500]) =>
      Future.delayed(Duration(milliseconds: ms));

  void _showMainMenu() {
    _addEntry(
      _Sender.npc,
      _ChoiceGroup(
        options: const [
          _ChoiceOption(icon: Icons.bolt, label: _questLabel),
          _ChoiceOption(icon: Icons.explore, label: '我想去附近晃晃……'),
        ],
        onSelected: _handleMainMenuChoice,
      ),
    );
  }

  void _handleMainMenuChoice(int index) {
    if (_guardBusy()) return;

    if (index == 0) {
      _userText('幫我找一個附近的隨機地點，讓我遊玩吧！');
      _runSpin(_questDefaultText);
    } else {
      _handleNearby();
    }
  }

  Future<void> _runSpin(String text) async {
    _busy = true;

    await _delay(200);
    if (!mounted) return;

    _showTyping();

    try {
      final Map<String, dynamic> result = await StoryApi.spinRecommendation(
        inputText: text,
      );

      if (!mounted) return;

      _hideTyping();

      _addEntry(
        _Sender.npc,
        _SpinResultCard(data: result),
        record: {'t': 'spin', 'data': result},
      );
    } catch (e) {
      if (!mounted) return;

      _hideTyping();
      _npcText(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy = false;
    }

    await _delay(300);
    if (!mounted) return;

    _showMainMenu();
  }

  Future<void> _handleNearby() async {
    _userText('我想找點附近去晃晃……');
    await _delay();
    if (!mounted) return;

    _npcText('您現在比較想找哪一類呢？');
    await _delay(300);
    if (!mounted) return;

    _addEntry(
      _Sender.npc,
      _ChoiceGroup(
        options: const [
          _ChoiceOption(icon: Icons.restaurant, label: '吃喝'),
          _ChoiceOption(icon: Icons.local_see, label: '其他'),
        ],
        onSelected: _handleNearbyCategory,
      ),
    );
  }

  Future<void> _handleNearbyCategory(int index) async {
    if (_guardBusy()) return;

    final bool food = index == 0;

    _userText(food ? '吃喝' : '其他');

    if (!NearbyCache.instance.hasData) {
      _busy = true;
      _showTyping();

      try {
        await NearbyCache.instance.refresh();
      } catch (e) {
        _hideTyping();
        _busy = false;

        if (!mounted) return;

        _npcText(e.toString().replaceFirst('Exception: ', ''));
        _showMainMenu();
        return;
      }

      _hideTyping();
      _busy = false;
    }

    await _delay(300);
    if (!mounted) return;

    final List<NearbyPlaceData> all = NearbyCache.instance.places;

    List<NearbyPlaceData> pool = all
        .where((place) => _isFood(place) == food)
        .toList();

    if (pool.isEmpty) {
      pool = List.of(all);
    }

    if (pool.isEmpty) {
      _npcText('附近兩公里內暫時沒有找到地方，換個地方再試試吧！');
      _showMainMenu();
      return;
    }

    pool.shuffle(_random);

    _pool = pool;
    _poolIndex = 0;

    _showNextNearby();
  }

  void _showNextNearby() {
    if (_poolIndex >= _pool.length) {
      _pool.shuffle(_random);
      _poolIndex = 0;
      _npcText('這一帶我都推薦過一輪了，再隨機挑給您：');
    }

    final int end = math.min(_poolIndex + 5, _pool.length);
    final List<NearbyPlaceData> batch = _pool.sublist(_poolIndex, end);

    _poolIndex = end;

    _addEntry(
      _Sender.npc,
      _NearbyListCard(places: batch),
      record: {
        't': 'nearby',
        'places': [
          for (final NearbyPlaceData p in batch)
            {'title': p.title, 'lat': p.lat, 'lon': p.lon, 'd': p.distanceM},
        ],
      },
    );

    _addEntry(
      _Sender.npc,
      _ChoiceGroup(
        options: const [
          _ChoiceOption(icon: Icons.refresh, label: '還有嗎?'),
          _ChoiceOption(icon: Icons.home_outlined, label: '回主選單'),
        ],
        onSelected: (index) {
          if (_guardBusy()) return;

          if (index == 0) {
            _userText('還有嗎?');
            _showNextNearby();
          } else {
            _userText('回主選單');
            _showMainMenu();
          }
        },
      ),
    );
  }

  void _sendFreeText() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_guardBusy()) return;
    _inputController.clear();
    _handleFreeText(text);
  }

  Future<void> _handleFreeText(String text) async {
    _userText(text);
    await _runSpin(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _Header(name: _npcName, subtitle: _npcSubtitle),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.4,
                    colors: [AppColors.warmPaper, AppColors.paper],
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _entries[i].child,
                  ),
                ),
              ),
            ),
            _InputBar(controller: _inputController, onSend: _sendFreeText),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// UI 元件：小精靈頭貼
// ===========================================================================

class _NpcAvatar extends StatelessWidget {
  final double size;
  const _NpcAvatar({this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.postcard,
        border: Border.all(
          color: AppColors.deepRed,
          width: size >= 44 ? 2.2 : 1.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        _kNpcAvatarAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.auto_awesome,
          size: size * 0.55,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

// ===========================================================================
// UI 元件：頂部藏寶圖卷軸標頭
// ===========================================================================

class _Header extends StatelessWidget {
  final String name;
  final String subtitle;
  const _Header({required this.name, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        border: const Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBrown.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.paper),
            tooltip: '返回上一頁',
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _NpcAvatar(size: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.paper,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.postcard,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.explore, color: AppColors.postcard, size: 28),
        ],
      ),
    );
  }
}

// ===========================================================================
// UI 元件：底部聊天輸入框
// ===========================================================================

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.warmPaper,
        border: const Border(
          top: BorderSide(color: AppColors.darkBorder, width: 2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.inputLine, width: 1.3),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: '想問小精靈些什麼呢……',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.inputHint,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onSend,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.darkBorder, width: 1.6),
                ),
                child: const Icon(Icons.send, color: AppColors.paper, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// UI 元件：對話泡泡
// ===========================================================================

class _NpcBubble extends StatelessWidget {
  final Widget child;
  const _NpcBubble({required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: _NpcAvatar(size: 34),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.darkBorder, width: 1.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withOpacity(0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  final Widget child;
  const _UserBubble({required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              border: Border.all(color: AppColors.darkBorder, width: 1.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBrown.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// UI 元件：選項按鈕群（羊皮紙票券風格）
// ===========================================================================

class _ChoiceGroup extends StatelessWidget {
  final List<_ChoiceOption> options;
  final ValueChanged<int> onSelected;
  const _ChoiceGroup({required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return _NpcBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '請選擇：',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.softBrown,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ChoiceButton(option: options[i], onTap: () => onSelected(i)),
          ],
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final _ChoiceOption option;
  final VoidCallback onTap;
  const _ChoiceButton({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.questionBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.postcardLine, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(option.icon, size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.label,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.softBrown),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  final bool ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );

  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('無法開啟')));
  }
}

Future<void> _openMap(BuildContext context, String query) {
  return _openUrl(
    context,
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
  );
}

String _distanceText(double meters) {
  return meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} 公里'
      : '${meters.round()} 公尺';
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = filled ? AppColors.paper : AppColors.primaryDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : AppColors.questionBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? AppColors.darkBorder : AppColors.postcardLine,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmallBold.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyListCard extends StatelessWidget {
  final List<NearbyPlaceData> places;

  const _NearbyListCard({required this.places});

  @override
  Widget build(BuildContext context) {
    return _NpcBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '這是我推薦的幾個地方：',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.softBrown,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < places.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PlaceRow(place: places[i]),
          ],
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final NearbyPlaceData place;

  const _PlaceRow({required this.place});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoryRouteMapPage(
              detourTo: PlacePoint(
                lat: place.lat,
                lng: place.lon,
                name: place.title,
              ),
            ),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.postcard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.postcardLine, width: 1.4),
          ),
          child: Row(
            children: [
              const Icon(Icons.place, size: 20, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.darkBrown,
                      ),
                    ),
                    Text(
                      '距離約 ${_distanceText(place.distanceM)}',
                      style: AppTextStyles.captionSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '前往',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.deepRed,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.near_me, size: 14, color: AppColors.deepRed),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpinResultCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SpinResultCard({required this.data});

  Map<String, dynamic> _map(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> agent = _map(data['agent_result']);
    final Map<String, dynamic> spot = _map(
      _map(agent['phase_3_graph_rag'])['recommended_spot'],
    );
    final Map<String, dynamic> tools = _map(agent['phase_4_action_and_tools']);

    final String name = _text(spot['name']);
    final String address = _text(spot['address']);
    final String description = _text(spot['description']);
    final String calendarUrl = _text(tools['tool_1_calendar_sync']);
    final double? distance = double.tryParse(_text(spot['distance_m']));
    final dynamic rawTags = spot['tags'];
    final List<String> tags = rawTags is List
        ? rawTags.map(_text).where((tag) => tag.isNotEmpty).toList()
        : [];

    return _NpcBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '為您找到這裡：',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.softBrown,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.postcard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.postcardLine, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTextStyles.subtitleMedium.copyWith(
                    color: AppColors.darkBrown,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (distance != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '目前距離約 ${_distanceText(distance)}',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.deepRed,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final String tag in tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.postcardLine),
                          ),
                          child: Text(
                            tag,
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (calendarUrl.isNotEmpty) ...[
                Expanded(
                  child: _ActionButton(
                    icon: Icons.event_available,
                    label: '加入行事曆',
                    filled: false,
                    onTap: () => _openUrl(context, calendarUrl),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionButton(
                  icon: Icons.near_me,
                  label: '前往',
                  filled: true,
                  onTap: () => _openMap(
                    context,
                    address.isNotEmpty ? '$name $address' : name,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> {
  Timer? _timer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) {
        setState(() => _dots = _dots % 3 + 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTextStyles.body.copyWith(
      color: AppColors.textPrimary,
    );

    return _NpcBubble(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('正在尋找', style: style),
          SizedBox(width: 24, child: Text('.' * _dots, style: style)),
        ],
      ),
    );
  }
}
