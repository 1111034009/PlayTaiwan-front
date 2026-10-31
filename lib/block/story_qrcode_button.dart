import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_responsive.dart';
import '../pages/story_qrcode_page.dart';

class StoryNfcButton extends StatelessWidget {
  const StoryNfcButton({super.key, this.onSuccess});

  final VoidCallback? onSuccess;

  Future<void> _openNfcPage(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const StoryNfcPage()));

    if (result == true) {
      onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double k = tabletBoost(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNfcPage(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: 60 * k,
          height: 60 * k,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
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
              'img/qr_code.png',
              width: 50 * k,
              height: 50 * k,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
