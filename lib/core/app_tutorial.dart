import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'app_session.dart';
import 'app_text_styles.dart';

export 'package:tutorial_coach_mark/tutorial_coach_mark.dart' show ContentAlign;

class TutorialKeys {
  TutorialKeys._();

  static final GlobalKey nfc = GlobalKey(debugLabel: 'tutorial_nfc');
  static final GlobalKey aiTalk = GlobalKey(debugLabel: 'tutorial_ai_talk');
}

class TutorialStep {
  final GlobalKey target;
  final String title;
  final String text;
  final ContentAlign align;

  const TutorialStep({
    required this.target,
    required this.title,
    required this.text,
    this.align = ContentAlign.bottom,
  });
}

class AppTutorial {
  AppTutorial._();

  static const String homeId = 'home';
  static const String selectionId = 'selection';
  static const String merchantHomeId = 'merchant_home';
  static String _prefKey(String id) =>
      'tutorial_${id}_done_v1_${AppSession.epId ?? AppSession.epName ?? ''}';

  static Future<bool> isDone(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey(id)) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markDone(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey(id), true);
    } catch (_) {}
  }

  static Future<void> reset(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey(id));
    } catch (_) {}
  }

  /// 目標元件現在在螢幕上的位置（沒有就回 null）
  static Rect? _rectOf(GlobalKey key) {
    final RenderObject? object = key.currentContext?.findRenderObject();

    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }

    final Size size = object.size;
    final List<Offset> corners = [
      object.localToGlobal(Offset.zero),
      object.localToGlobal(Offset(size.width, 0)),
      object.localToGlobal(Offset(0, size.height)),
      object.localToGlobal(Offset(size.width, size.height)),
    ];

    double left = corners.first.dx;
    double top = corners.first.dy;
    double right = corners.first.dx;
    double bottom = corners.first.dy;

    for (final Offset corner in corners) {
      left = math.min(left, corner.dx);
      top = math.min(top, corner.dy);
      right = math.max(right, corner.dx);
      bottom = math.max(bottom, corner.dy);
    }

    final Rect rect = Rect.fromLTRB(left, top, right, bottom);

    if (rect.width <= 0 || rect.height <= 0) return null;

    return rect;
  }

  static TargetPosition? _positionOf(GlobalKey key, Size screen) {
    final Rect? rect = _rectOf(key);

    if (rect == null) return null;
    if (!(Offset.zero & screen).overlaps(rect)) return null;

    return TargetPosition(rect.size, rect.topLeft);
  }

  /// 等到「鍵盤收起來」而且「所有目標的位置連續 3 個 frame 都沒動」才回傳。
  /// 從登入頁（鍵盤還開著、版面被縮小）跳過來時，
  /// 頁面會先在縮小的版面上畫一次，再彈回正常大小，這時量的位置是錯的。
  /// 最多等 3 秒，超過就用目前的位置。
  static Future<bool> _waitUntilSettled(
    BuildContext context,
    List<GlobalKey> keys,
  ) async {
    final Stopwatch watch = Stopwatch()..start();
    List<Rect?>? last;
    int stable = 0;

    while (watch.elapsed < const Duration(seconds: 3)) {
      await WidgetsBinding.instance.endOfFrame;

      if (!context.mounted) return false;

      final bool keyboardOpen = View.of(context).viewInsets.bottom > 0;
      final List<Rect?> now = [for (final GlobalKey key in keys) _rectOf(key)];

      if (!keyboardOpen && last != null && _sameRects(last, now)) {
        stable++;
      } else {
        stable = 0;
      }

      last = now;

      if (stable >= 3) return true;
    }

    return context.mounted;
  }

  static bool _sameRects(List<Rect?> a, List<Rect?> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      final Rect? x = a[i];
      final Rect? y = b[i];

      if (x == null || y == null) {
        if (x != y) return false;
        continue;
      }

      if ((x.left - y.left).abs() > 0.5 ||
          (x.top - y.top).abs() > 0.5 ||
          (x.width - y.width).abs() > 0.5 ||
          (x.height - y.height).abs() > 0.5) {
        return false;
      }
    }

    return true;
  }

  static Widget _bubble(TutorialStep step, int index, int total) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.title,
          style: AppTextStyles.title.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          step.text,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          '$index / $total．點一下繼續',
          style: AppTextStyles.caption.copyWith(color: const Color(0xFFFFD76A)),
        ),
      ],
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String id,
    required List<TutorialStep> steps,
  }) async {
    // 等鍵盤收起、版面穩定後才量位置，避免定位跑掉
    final bool ready = await _waitUntilSettled(context, [
      for (final TutorialStep step in steps) step.target,
    ]);

    if (!ready || !context.mounted) return;

    final Size screen = MediaQuery.sizeOf(context);
    final List<TutorialStep> usable = [];
    final List<TargetPosition> positions = [];

    for (final TutorialStep step in steps) {
      final TargetPosition? position = _positionOf(step.target, screen);

      if (position == null) continue;

      usable.add(step);
      positions.add(position);
    }

    if (usable.isEmpty) return;

    final List<TargetFocus> targets = [
      for (int i = 0; i < usable.length; i++)
        TargetFocus(
          identify: 'step_$i',
          targetPosition: positions[i],
          shape: ShapeLightFocus.RRect,
          radius: 14,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: usable[i].align,
              child: _bubble(usable[i], i + 1, usable.length),
            ),
          ],
        ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.82,
      paddingFocus: 6,
      useSafeArea: true,
      textSkip: '跳過',
      textStyleSkip: AppTextStyles.bodySmallBold.copyWith(color: Colors.white),
      alignSkip: Alignment.topRight,
      onFinish: () {
        markDone(id);
      },
      onSkip: () {
        markDone(id);
        return true;
      },
    ).show(context: context);
  }
}
