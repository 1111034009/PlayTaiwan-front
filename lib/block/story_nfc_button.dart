import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../pages/story_nfc_page.dart';

class StoryNfcButton extends StatelessWidget {
  const StoryNfcButton({
    super.key,
    this.locationName = '臺南孔廟',
    this.sealName = '康熙御筆',
    this.rewardText = '臺南孔廟專屬店家優惠券',
    this.onSuccess,
  });

  final String locationName;
  final String sealName;
  final String rewardText;
  final VoidCallback? onSuccess;

  Future<void> _openNfcPage(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StoryNfcPage(
          locationName: locationName,
          sealName: sealName,
          rewardText: rewardText,
        ),
      ),
    );

    if (result == true) {
      onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNfcPage(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
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
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
