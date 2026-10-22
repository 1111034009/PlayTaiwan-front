import 'package:flutter/material.dart';
import 'dart:async';
import '../core/app_text_styles.dart';
import '../pages/ai_talk_page.dart';
import 'ai_talk_button.dart';
import 'story_qrcode_button.dart';

class ShellNoticeData {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const ShellNoticeData(this.message, this.actionLabel, this.onAction);
}

class ShellNotice {
  ShellNotice._();

  static final ValueNotifier<ShellNoticeData?> current = ValueNotifier(null);
  static Timer? _timer;

  static void show(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    _timer?.cancel();
    current.value = ShellNoticeData(message, actionLabel, onAction);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    current.value = null;
  }
}

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
        ValueListenableBuilder<ShellNoticeData?>(
          valueListenable: ShellNotice.current,
          builder: (context, data, _) {
            if (data == null) return const SizedBox.shrink();
            return Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: Material(
                  color: const Color(0xFF40342D),
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.message,
                            style: AppTextStyles.bodySmallBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (data.actionLabel != null)
                          TextButton(
                            onPressed: () {
                              ShellNotice.hide();
                              data.onAction?.call();
                            },
                            child: Text(
                              data.actionLabel!,
                              style: AppTextStyles.bodySmallBold.copyWith(
                                color: const Color(0xFFFFD76A),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
