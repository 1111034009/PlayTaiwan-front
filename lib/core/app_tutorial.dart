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

  static TargetPosition? _positionOf(GlobalKey key, Size screen) {
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
    if (!(Offset.zero & screen).overlaps(rect)) return null;

    return TargetPosition(rect.size, rect.topLeft);
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

  static void show(
    BuildContext context, {
    required String id,
    required List<TutorialStep> steps,
  }) {
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
