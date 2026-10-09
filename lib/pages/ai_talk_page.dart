import 'package:flutter/material.dart';

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

/// 已加入探員行事曆的行程資料
class _CalendarEvent {
  final String title;
  final String spots;
  final String date;
  const _CalendarEvent({
    required this.title,
    required this.spots,
    required this.date,
  });
}

class _Category {
  final String label;
  final IconData icon;
  final List<_Destination> destinations;
  const _Category({
    required this.label,
    required this.icon,
    required this.destinations,
  });
}

class _Destination {
  final String title;
  final String spots;
  final String date;
  const _Destination({
    required this.title,
    required this.spots,
    required this.date,
  });
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
  static const String _npcSubtitle = '探員隨身導覽';

  final List<_Entry> _entries = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final List<_CalendarEvent> _calendarEvents = [];

  static const List<_Category> _categories = [
    _Category(
      label: '吃喝',
      icon: Icons.restaurant,
      destinations: [
        _Destination(
          title: '度小月擔仔麵',
          spots: '國華街本店，招牌擔仔麵、蝦捲',
          date: '營業時間：11:00 ～ 20:30',
        ),
        _Destination(
          title: '窄門咖啡',
          spots: '府中街巷弄老宅咖啡，招牌桂花拿鐵',
          date: '營業時間：10:00 ～ 18:00',
        ),
        _Destination(
          title: '正興街冰品店',
          spots: '在地排隊冰品，芒果雪花冰必吃',
          date: '營業時間：12:00 ～ 21:00',
        ),
      ],
    ),
    _Category(
      label: '休息',
      icon: Icons.self_improvement,
      destinations: [
        _Destination(
          title: '林默娘公園',
          spots: '河堤景觀綠地，適合吹風賞夕陽',
          date: '開放時間：全天開放',
        ),
        _Destination(
          title: '不只是圖書館',
          spots: '老屋改建的靜謐閱讀空間，可小憩片刻',
          date: '營業時間：10:00 ～ 18:00',
        ),
        _Destination(
          title: '神農街老宅茶館',
          spots: '古厝改建茶館，品茶放空',
          date: '營業時間：13:00 ～ 20:00',
        ),
      ],
    ),
    _Category(
      label: '逛街',
      icon: Icons.shopping_bag,
      destinations: [
        _Destination(
          title: '正興街商圈',
          spots: '文創小店、選物店林立',
          date: '營業時間：11:00 ～ 21:00',
        ),
        _Destination(
          title: '神農街文創聚落',
          spots: '老屋改建工作室與選物店',
          date: '營業時間：11:00 ～ 19:00',
        ),
        _Destination(
          title: '林百貨',
          spots: '複合式百貨，文創商品與伴手禮',
          date: '營業時間：10:30 ～ 21:00',
        ),
      ],
    ),
  ];

  static const Map<String, List<String>> _categoryKeywords = {
    '吃喝': ['吃', '喝', '美食', '小吃', '咖啡', '甜點', '宵夜', '餓', '奶茶'],
    '休息': ['休息', '累', '放空', '涼快', '冷氣', '吹冷氣', '避暑', '太熱', '熱', '發呆', '喘口氣'],
    '逛街': ['逛街', '購物', '買', '商圈', '百貨', '逛逛'],
  };

  _Category? _matchCategory(String text) {
    for (final category in _categories) {
      final keywords = _categoryKeywords[category.label] ?? const [];
      for (final kw in keywords) {
        if (text.contains(kw)) return category;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _npcText('探員閣下您好，今日想找我做點甚麼呢?');
    _showMainMenu();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // 對話輔助方法
  // ---------------------------------------------------------------------

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

  void _addEntry(_Sender sender, Widget child) {
    setState(() => _entries.add(_Entry(sender, child)));
    _scrollToBottom();
  }

  void _npcText(String text) {
    _addEntry(_Sender.npc, _NpcBubble(child: Text(text, style: _npcTextStyle)));
  }

  void _userText(String text) {
    _addEntry(
      _Sender.user,
      _UserBubble(child: Text(text, style: _userTextStyle)),
    );
  }

  TextStyle get _npcTextStyle =>
      AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.4);

  TextStyle get _userTextStyle =>
      AppTextStyles.body.copyWith(color: AppColors.paper, height: 1.4);

  Future<void> _delay([int ms = 500]) =>
      Future.delayed(Duration(milliseconds: ms));

  // ---------------------------------------------------------------------
  // 主選單 / 三個開場選項
  // ---------------------------------------------------------------------

  void _showMainMenu() {
    _addEntry(
      _Sender.npc,
      _ChoiceGroup(
        options: const [
          _ChoiceOption(icon: Icons.auto_stories, label: '開一個劇本給我'),
          _ChoiceOption(icon: Icons.explore, label: '我想找點地方去晃晃……'),
          _ChoiceOption(icon: Icons.chat_bubble_outline, label: '只是想找你聊聊天'),
        ],
        onSelected: _handleMainMenuChoice,
      ),
    );
  }

  void _handleMainMenuChoice(int index) {
    switch (index) {
      case 0:
        _handleOpenQuest();
        break;
      case 1:
        _handleFindPlaces();
        break;
      case 2:
        _handleCasualChat();
        break;
    }
  }

  // ---------------------------------------------------------------------
  // 選項一：開一個劇本給我
  // ---------------------------------------------------------------------

  Future<void> _handleOpenQuest() async {
    _userText('幫我開一個新的劇本吧！');
    await _delay();
    if (!mounted) return;
    _addEntry(
      _Sender.npc,
      const _QuestScrollCard(
        title: '古都密令：失落的印記',
        objective: '前往指定地點尋找三個隱藏印記，並拍照回報給我確認。',
        reward: '獎勵：探索積分 x30、限定明信片一張',
      ),
    );
    await _delay(400);
    if (!mounted) return;
    _npcText('劇本卷軸已經交給您了，完成後記得回來找我回報喔！');
    await _delay(400);
    if (!mounted) return;
    _showMainMenu();
  }

  // ---------------------------------------------------------------------
  // 選項二：我想找點地方去晃晃……（吃喝 / 休息 / 逛街）
  // ---------------------------------------------------------------------

  Future<void> _handleFindPlaces() async {
    _userText('我想找點地方去晃晃……');
    await _delay();
    if (!mounted) return;
    _npcText('您現在比較想做些什麼呢？');
    await _delay(300);
    if (!mounted) return;
    _addEntry(
      _Sender.npc,
      _ChoiceGroup(
        options: _categories
            .map((c) => _ChoiceOption(icon: c.icon, label: c.label))
            .toList(),
        onSelected: _handleCategoryChoice,
      ),
    );
  }

  Future<void> _handleCategoryChoice(int index) async {
    final category = _categories[index];
    _userText('我想找點${category.label}的地方～');
    await _delay();
    if (!mounted) return;
    _npcText('這是我推薦的幾個地方，您可以參考看看：');
    await _delay(300);
    if (!mounted) return;
    _addEntry(
      _Sender.npc,
      _ChoiceGroup(
        options: category.destinations
            .map((d) => _ChoiceOption(icon: Icons.place, label: d.title))
            .toList(),
        onSelected: (i) => _handleDestinationChoice(category, i),
      ),
    );
  }

  Future<void> _handleDestinationChoice(_Category category, int index) async {
    final dest = category.destinations[index];
    _userText('我想去【${dest.title}】看看！');
    await _delay();
    if (!mounted) return;
    _addEntry(
      _Sender.npc,
      _TripCard(destination: dest, onConfirm: () => _confirmTrip(dest)),
    );
  }

  Future<void> _confirmTrip(_Destination dest) async {
    setState(() {
      _calendarEvents.add(
        _CalendarEvent(title: dest.title, spots: dest.spots, date: dest.date),
      );
    });
    await _delay(300);
    if (!mounted) return;
    _addEntry(
      _Sender.system,
      _SystemNotice(
        title: '已成功加入探員行事曆！',
        message: '「${dest.title}」已排定至您的專屬任務清單中。',
        totalEvents: _calendarEvents.length,
      ),
    );
    await _delay(400);
    if (!mounted) return;
    _npcText('探員還想繼續規劃，還是找我聊點別的呢？');
    await _delay(300);
    if (!mounted) return;
    _showMainMenu();
  }

  // ---------------------------------------------------------------------
  // 選項三：只是想找你聊聊天
  // ---------------------------------------------------------------------

  Future<void> _handleCasualChat() async {
    _userText('只是想找你聊聊天～');
    await _delay();
    if (!mounted) return;
    _npcText('當然可以!探員辛苦了！我一直都在您身邊，隨時可以問我路線、劇本或周邊小情報喔。');
    await _delay(500);
    if (!mounted) return;
    _showMainMenu();
  }

  // ---------------------------------------------------------------------
  // 自由輸入對話框
  // ---------------------------------------------------------------------

  void _sendFreeText() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    _handleFreeText(text);
  }

  Future<void> _handleFreeText(String text) async {
    _userText(text);
    await _delay();
    if (!mounted) return;

    final matched = _matchCategory(text);
    if (matched != null) {
      _npcText('聽起來您想找地方${matched.label}一下，這是我推薦的幾個地方：');
      await _delay(300);
      if (!mounted) return;
      _addEntry(
        _Sender.npc,
        _ChoiceGroup(
          options: matched.destinations
              .map((d) => _ChoiceOption(icon: Icons.place, label: d.title))
              .toList(),
          onSelected: (i) => _handleDestinationChoice(matched, i),
        ),
      );
      return;
    }

    _npcText('探員說的是「$text」呀，這部分我還在學習中，您可以參考上面的選項，或告訴我想找吃喝、休息還是逛街的地方！');
    await _delay(300);
    if (!mounted) return;
    _showMainMenu();
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

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

// ===========================================================================
// UI 元件：劇本卷軸卡片
// ===========================================================================

class _QuestScrollCard extends StatelessWidget {
  final String title;
  final String objective;
  final String reward;
  const _QuestScrollCard({
    required this.title,
    required this.objective,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    return _NpcBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                '新劇本已解鎖',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                  title,
                  style: AppTextStyles.subtitleMedium.copyWith(
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  objective,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reward,
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.deepRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// UI 元件：地點建議卡片（含確認並加入行事曆）
// ===========================================================================

class _TripCard extends StatelessWidget {
  final _Destination destination;
  final VoidCallback onConfirm;
  const _TripCard({required this.destination, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return _NpcBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '這裡是詳細資訊：',
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
                  destination.title,
                  style: AppTextStyles.subtitleMedium.copyWith(
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination.spots,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination.date,
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.deepRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '請按下方按鈕確認加入您的探員行事曆：',
            style: AppTextStyles.captionSmall.copyWith(
              color: AppColors.softBrown,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onConfirm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.darkBorder, width: 1.6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.beenhere,
                      size: 18,
                      color: AppColors.paper,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '確認並加入行事曆',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.paper,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// UI 元件：系統提示（成功加入行事曆）
// ===========================================================================

class _SystemNotice extends StatelessWidget {
  final String title;
  final String message;
  final int totalEvents;
  const _SystemNotice({
    required this.title,
    required this.message,
    required this.totalEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.merchantPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.progressValue, width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available,
                size: 18,
                color: AppColors.progressValue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.progressValue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '探員行事曆目前共有 $totalEvents 筆行程',
            style: AppTextStyles.captionSmall.copyWith(
              color: AppColors.softBrown,
            ),
          ),
        ],
      ),
    );
  }
}
