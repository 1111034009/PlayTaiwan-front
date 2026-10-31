import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../pages/ai_talk_page.dart';

class AiTalkButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AiTalkButton({super.key, this.onTap});

  void _openAiTalk(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AiTalkPage()));
  }

  @override
  Widget build(BuildContext context) {
    final double k = tabletBoost(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => _openAiTalk(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: 60 * k,
          height: 60 * k,
          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: Colors.transparent,

            border: Border.all(color: AppColors.darkBrown, width: 2.5),

            boxShadow: [
              BoxShadow(
                color: AppColors.darkBrown.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),

          padding: const EdgeInsets.all(2.5),

          child: ClipOval(
            child: Image.asset(
              'img/talk_cat.png',
              width: 55 * k,
              height: 55 * k,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
