import 'package:flutter/material.dart';

import '../pages/ai_talk_page.dart';
import 'ai_talk_button.dart';
import 'story_nfc_button.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  void _openAiTalk(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AiTalkPage()));
  }

  void _showNfcSuccessSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('NFC 驗證成功！', textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 90),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 頁面內容
        Positioned.fill(child: child),

        // 右下角浮動按鈕
        Positioned(
          right: 14,
          bottom: 92,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,

              // 兩個按鈕水平置中
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                // NFC
                StoryNfcButton(
                  onSuccess: () {
                    _showNfcSuccessSnackBar(context);
                  },
                ),

                const SizedBox(height: 10),

                // AI 對話
                AiTalkButton(onTap: () => _openAiTalk(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
