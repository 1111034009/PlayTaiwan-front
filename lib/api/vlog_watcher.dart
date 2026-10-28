import 'dart:async';

import 'package:flutter/material.dart';
import '../core/app_notice.dart';
import 'story_api.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class VlogWatcher {
  const VlogWatcher._();
  static Timer? _timer;
  static bool _busy = false;
  static int _ticks = 0;

  static void start({required String storyId, required String taskId}) {
    _timer?.cancel();
    _ticks = 0;

    _show('Vlog 已送出，會在背景製作，完成後通知你', seconds: 6);

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _poll(storyId, taskId),
    );
  }

  static Future<void> _poll(String storyId, String taskId) async {
    if (_busy) return;

    _ticks++;

    if (_ticks > 360) {
      _timer?.cancel();
      return;
    }

    _busy = true;

    try {
      final Map<String, dynamic> result = await StoryApi.visitorVlogStatus(
        storyId: storyId,
        taskId: taskId,
      );

      final int status = int.tryParse(result['status']?.toString() ?? '') ?? 0;

      if (status == 3) {
        _timer?.cancel();
        _show('Vlog 製作完成！請至「過往」查看', seconds: 8);
      } else if (status == 4) {
        _timer?.cancel();

        final String reason = result['error_message']?.toString().trim() ?? '';

        _show(reason.isEmpty ? 'Vlog 製作失敗' : 'Vlog 製作失敗：$reason', seconds: 8);
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  static void _show(String message, {int seconds = 4}) {
    AppNotice.show(message, duration: Duration(seconds: seconds));
  }
}
