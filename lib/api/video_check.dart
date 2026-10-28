import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_notice.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/auth_guard.dart';
import '../pages/merchant_video_page.dart';
import 'merchant_vlog_api.dart';

class VideoCheck {
  VideoCheck._();

  static const Duration _interval = Duration(seconds: 2);
  static const Duration _maxWait = Duration(minutes: 15);

  static final Map<int, Timer> _timers = {};
  static final Set<int> _busy = {};

  static void watch(int mmId, {String title = ''}) {
    if (_timers.containsKey(mmId)) return;

    final startedAt = DateTime.now();

    _timers[mmId] = Timer.periodic(_interval, (_) async {
      if (_busy.contains(mmId)) return;
      _busy.add(mmId);

      try {
        final status = await MerchantVlogApi.fetchStatus(mmId);

        if (status.isCompleted) {
          _stop(mmId);
          _notify(title.isEmpty ? '影片已生成完成' : '「$title」影片已生成完成', openId: mmId);
        } else if (status.isFailed) {
          _stop(mmId);
          _notify(
            status.errorMessage.isEmpty
                ? '影片生成失敗，請重新嘗試'
                : '影片生成失敗：${status.errorMessage}',
          );
        } else if (DateTime.now().difference(startedAt) > _maxWait) {
          _stop(mmId);
        }
      } catch (_) {
      } finally {
        _busy.remove(mmId);
      }
    });
  }

  static void _stop(int mmId) {
    _timers.remove(mmId)?.cancel();
  }

  static void _notify(String message, {int? openId}) {
    final context = AuthGuard.navigatorKey.currentContext;
    if (context == null) return;

    AppNotice.show(message, duration: const Duration(seconds: 8));
  }
}
