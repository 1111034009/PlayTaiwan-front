import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'place_ticket.dart';

/// 天氣圖示：後端 GET /api/Map/Weather 的 condition
IconData weatherIcon(String? condition) => switch (condition) {
      'clear' => Icons.wb_sunny,
      'cloudy' => Icons.wb_cloudy,
      'overcast' => Icons.cloud,
      'fog' => Icons.foggy,
      'rain' => Icons.umbrella,
      'thunder' => Icons.thunderstorm,
      'snow' => Icons.ac_unit,
      _ => Icons.thermostat,
    };

/// 地圖上的 NPC：平常只是角落的一個頭像，不擋畫面；有話要說才跳出對話泡泡。
/// 什麼時候該說話（快下雨、太熱、用餐時間…）由後端判斷，這裡只管畫。
/// 點頭像可以自己問；泡泡上可以換問「天氣」或「吃什麼」。
/// 寬螢幕放在右下角，泡泡往左長；手機放在左下角，泡泡往右長
class NpcBuddy extends StatelessWidget {
  const NpcBuddy({
    super.key,
    required this.onTap,
    required this.onAsk,
    this.avatar,
    this.name,
    this.avatarUrl,
    this.kind,
    this.text,
    this.icon,
    this.busy = false,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  /// 點頭像（有給 [avatar] 時不會用到，那個頭像自己處理點擊）
  final VoidCallback onTap;

  /// 外面給的頭像（正式 App 右下角那隻貓）：原樣畫出來，固定放在右邊，泡泡往左長。沒給就畫這份劇本的 NPC
  final Widget? avatar;

  /// 泡泡上的「天氣」「吃什麼」，傳回 'weather' 或 'meal'
  final void Function(String kind) onAsk;
  final String? name;
  final String? avatarUrl;

  /// 現在泡泡在講什麼：'weather' 或 'meal'
  final String? kind;

  /// 泡泡裡的話；null = 沒有泡泡
  final String? text;
  final IconData? icon;

  /// 正在問後端
  final bool busy;

  /// 泡泡上的連結，例如「看 5 間店家」
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900 || this.avatar != null;
    final placeholder = const ColoredBox(color: Pal.parchmentDeep, child: Icon(Icons.face, color: Pal.inkSoft, size: 26));
    final avatar = this.avatar ?? Tooltip(
      message: name == null || name!.isEmpty ? 'NPC' : name!,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PlaceTicket.frame, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2))],
          ),
          child: ClipOval(
            child: Stack(fit: StackFit.expand, children: [
              (avatarUrl ?? '').isEmpty
                  ? placeholder
                  : Image.network(avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
              if (busy)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
    final bubble = text == null ? null : ConstrainedBox(constraints: BoxConstraints(maxWidth: math.min(270.0, width - 130)), child: _bubble());
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (wide && bubble != null) ...[bubble, const SizedBox(width: 6)],
      avatar,
      if (!wide && bubble != null) ...[const SizedBox(width: 6), bubble],
    ]);
  }

  Widget _bubble() => Material(
        color: const Color(0xF7F3E4C1),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: PlaceTicket.frame, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: Pal.cinnabar), const SizedBox(width: 6)],
              Flexible(child: Text(text!, style: const TextStyle(fontSize: 13, color: Pal.ink, height: 1.4))),
            ]),
            const SizedBox(height: 2),
            // 螢幕很窄時按鈕排不下一行就換行
            Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              _ask('天氣', 'weather'),
              _ask('吃什麼', 'meal'),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                  child: Text(actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              IconButton(
                tooltip: '收起來',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 16, color: Pal.inkSoft),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ]),
          ]),
        ),
      );

  /// 泡泡上換話題的小按鈕，現在在講的那個是深色的
  Widget _ask(String label, String value) {
    final selected = kind == value;
    return InkWell(
      onTap: selected ? null : () => onAsk(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? Pal.ink : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Pal.inkSoft),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: selected ? Pal.parchment : Pal.ink)),
      ),
    );
  }
}
