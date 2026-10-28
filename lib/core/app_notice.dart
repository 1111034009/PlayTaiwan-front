import 'dart:async';

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'auth_guard.dart';

class _NoticeItem {
  final String message;
  Timer? timer;

  _NoticeItem(this.message);
}

class AppNotice {
  AppNotice._();

  static final List<_NoticeItem> _items = [];
  static final ValueNotifier<int> _tick = ValueNotifier(0);
  static OverlayEntry? _entry;

  static void show(
    String message, {
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final OverlayState? overlay = AuthGuard.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _NoticeItem? existing;
    for (final _NoticeItem item in _items) {
      if (item.message == message) existing = item;
    }

    final _NoticeItem item = existing ?? _NoticeItem(message);
    item.timer?.cancel();
    item.timer = Timer(duration, () => _remove(item));
    if (existing == null) _items.add(item);

    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _NoticeHost());
      overlay.insert(_entry!);
    }

    _tick.value++;
  }

  static void _remove(_NoticeItem item) {
    item.timer?.cancel();
    _items.remove(item);

    if (_items.isEmpty) {
      _entry?.remove();
      _entry = null;
    }

    _tick.value++;
  }

  static void clear() {
    for (final _NoticeItem item in _items) {
      item.timer?.cancel();
    }
    _items.clear();
    _entry?.remove();
    _entry = null;
    _tick.value++;
  }
}

class _NoticeHost extends StatelessWidget {
  const _NoticeHost();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: AppNotice._tick,
            builder: (context, _, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final _NoticeItem item in AppNotice._items)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.storyBackground.withValues(
                          alpha: 0.95,
                        ),
                        border: Border.all(color: AppColors.postcard, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        item.message,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmallBold.copyWith(
                          color: AppColors.paper,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
