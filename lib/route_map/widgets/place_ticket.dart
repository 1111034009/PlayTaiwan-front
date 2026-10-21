import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../theme.dart';

/// 車票的外形，照正式 App 的 img/ticket.png 畫：外圈一道土黃色的框，裡面是米色的票面、咖啡色的細線，
/// 右邊一條票根（一道實線隔開，中間一道虛線），虛線上下兩端各有一個半圓的缺口（挖空，看得到後面的地圖）。
/// 用畫的不用那張圖：卡片的高度會跟著內容變，圖拉長壓扁缺口會變形
class _TicketPainter extends CustomPainter {
  const _TicketPainter();

  /// 外框的寬度
  static const band = 5.0;

  /// 票根的寬度（從實線到卡片右緣）
  static const stub = 46.0;
  static const _notch = 12.0;

  static const _bandColor = Color(0xFFC9B07A);
  static const _paper = Color(0xFFEAE0C6);
  static const _line = Color(0xFF8C7A68);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 虛線在票根的正中間，缺口的圓心在它的上下兩端
    final dashX = w - band - (stub - band) / 2;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(dashX, 0), radius: _notch))
      ..addOval(Rect.fromCircle(center: Offset(dashX, h), radius: _notch));
    Path cut(RRect shape) => Path.combine(PathOperation.difference, Path()..addRRect(shape), notches);
    final outer = cut(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)));
    final inner = cut(RRect.fromRectAndRadius(Rect.fromLTRB(band, band, w - band, h - band), const Radius.circular(3)));
    final line = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawPath(
      outer.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(outer, Paint()..color = _bandColor);
    canvas.drawPath(inner, Paint()..color = _paper);
    canvas.drawPath(inner, line);
    canvas.drawPath(outer, line);

    canvas.drawLine(Offset(w - stub, band), Offset(w - stub, h - band), line);
    final dash = Paint()
      ..color = _line
      ..strokeWidth = 1.6;
    final bottom = h - _notch - 5;
    for (var y = _notch + 5; y < bottom; y += 10) {
      canvas.drawLine(Offset(dashX, y), Offset(dashX, math.min(y + 6, bottom)), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPainter oldDelegate) => false;
}

/// 周邊好去／劇本景點的票券卡片，外形照正式 App 的車票（img/ticket.png，見 [_TicketPainter]）。
/// 點地圖上的地點時浮在地圖上，名稱右邊的 × 關閉。手機用 compact（照片在左、文字在右），少蓋一點地圖。
class PlaceTicket extends StatelessWidget {
  const PlaceTicket({
    super.key,
    required this.place,
    this.title,
    this.note,
    this.compact = false,
    this.locked = false,
    this.onClose,
    this.onGo,
    this.buttons = const [],
    this.link,
  });

  final NearbyPlace place;

  /// 卡片上的名稱，沒給就用地點名稱。還沒破關的景點給代號，不洩漏真名
  final String? title;

  /// 營業時間後面的補充，例如「距「西門町」82 m」「劇本第 3 站」
  final String? note;
  final bool compact;

  /// 還沒解鎖的景點：不顯示照片、營業時間、前往地址
  final bool locked;
  final VoidCallback? onClose;

  /// 有給的話「前往」是在我們的地圖上規劃路線過去，不開外部地圖
  final VoidCallback? onGo;

  /// 卡片最下面的按鈕（劇本景點：周邊好去、查看任務）和右邊的文字連結（回顧劇情）
  final List<({String label, VoidCallback onTap})> buttons;
  final ({String label, VoidCallback onTap})? link;

  static const frame = Color(0xFFA88D62);
  static const paper = Color(0xFFEFE5CB);
  static const card = Color(0xFFEBDFC0);
  static const _photoBg = Color(0xFFE0D0A8);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _TicketPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_TicketPainter.band + 8, _TicketPainter.band + 6, _TicketPainter.stub + 6, _TicketPainter.band + 6),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final photos = locked ? const <String>[] : place.photoUrls;
    // 名稱那一行的最右邊是關閉（票根留給虛線和缺口，跟正式 App 的車票一樣不放東西）
    final title = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Text(this.title ?? place.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Pal.cinnabar, height: 1.25)),
      ),
      if (onClose != null)
        // 不用 IconButton：它會把點擊範圍撐到 48，名稱那一行跟著變高
        Tooltip(
          message: '關閉',
          child: InkWell(
            onTap: onClose,
            customBorder: const CircleBorder(),
            child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close, size: 18, color: Pal.inkSoft)),
          ),
        ),
    ]);
    // 沒有營業時間但有補充說明（第幾關、距離）時，只顯示補充說明
    final hours = locked || (place.openTime == null && note != null) ? null : (place.openTime ?? '營業時間未提供');
    final info = Text.rich(TextSpan(children: [
      if (hours != null)
        TextSpan(text: hours, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Pal.ink)),
      if (note != null)
        TextSpan(text: hours == null ? note : '・$note', style: TextStyle(fontSize: hours == null ? 12 : 11, color: Pal.inkSoft)),
    ]));
    final actions = Row(children: [
      Expanded(
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          if (locked) _chip('未解鎖') else _chip(place.categoryLabel),
          if (!locked && place.type != null && place.type!.isNotEmpty) _chip(place.type!),
        ]),
      ),
      if (!locked && onGo != null)
        _linkButton('前往', onGo!, icon: Icons.near_me_outlined)
      else if (!locked && place.mapsUrl != null)
        _goButton(context, place.mapsUrl!),
    ]);
    final more = buttons.isEmpty && link == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 4, children: [for (final b in buttons) _button(b.label, b.onTap)]),
              ),
              if (link != null) _linkButton(link!.label, link!.onTap),
            ]),
          );

    if (compact) {
      // 卡片窄的時候（手機上右邊要讓出地圖的工具列）照片跟著縮，名稱和說明才放得下
      return LayoutBuilder(builder: (context, constraints) {
        final photoWidth = (constraints.maxWidth * 0.38).clamp(76.0, 104.0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _photo(photos.isEmpty ? null : photos.first,
                width: photoWidth, height: photoWidth * 72 / 104, icon: locked ? Icons.lock_outline : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 2), info]),
            ),
          ]),
          const SizedBox(height: 6),
          actions,
          ?more,
        ]);
      });
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      title,
      const SizedBox(height: 2),
      info,
      const SizedBox(height: 8),
      // 沒有照片時放兩個空框；只有一張時放大一點，不留空位
      Row(children: [
        if (locked)
          _photo(null, width: 168, height: 104, icon: Icons.lock_outline)
        else if (photos.isEmpty)
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _photo(null),
          ]
        else if (photos.length == 1)
          _photo(photos.first, width: 168, height: 104)
        else
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _photo(photos[i]),
          ],
      ]),
      const SizedBox(height: 8),
      actions,
      ?more,
    ]);
  }

  Widget _photo(String? url, {double width = 92, double height = 64, IconData? icon}) {
    final placeholder = Icon(icon ?? Icons.image_outlined, color: frame, size: 22);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _photoBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: frame.withValues(alpha: 0.5)),
      ),
      child: url == null ? placeholder : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: frame, width: 1.2),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Pal.ink)),
      );

  /// 「前往地址」：開外部地圖（Google Maps）
  Widget _goButton(BuildContext context, String url) => _linkButton('前往地址', () async {
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟地圖')));
        }
      }, icon: Icons.near_me_outlined);

  /// 紅字的文字連結（前往、回顧劇情）
  Widget _linkButton(String label, VoidCallback onTap, {IconData? icon}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Pal.cinnabar)),
            if (icon != null) ...[const SizedBox(width: 3), Icon(icon, size: 14, color: Pal.cinnabar)],
          ]),
        ),
      );

  /// 紅底白字的按鈕（周邊好去、查看任務）
  Widget _button(String label, VoidCallback onTap) => Material(
        color: Pal.cinnabar,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      );

}
