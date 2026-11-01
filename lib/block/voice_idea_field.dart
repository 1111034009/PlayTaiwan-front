import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/app_colors.dart';
import '../core/app_notice.dart';
import '../core/app_text_styles.dart';
import '../core/bgm_service.dart';

// ======================================================================
// 「遊你說了算」的輸入欄：可打字，也可錄音。
//
//   手動輸入 ──點麥克風──▶ 錄音中（顯示秒數）
//        ▲                      │ 點停止（至少錄 5 秒）/ 滿 60 秒自動停
//        │                      ▼
//        └────── 點 ✕ ◀──── 確認中：▶ 播放原本的錄音（可重複）／🎤 重錄／✕ 變回手動輸入
//
// 確認沒問題再按外面的「開始」：外面會把錄音檔交給 VoiceApi.transcribe 轉成文字
// （API 之後補），文字會填進輸入欄再去生成。
//
// 輸入欄本身只放文字／錄音狀態；錄音的按鈕（麥克風、停止、播放、✕）改放在外面「開始」按鈕旁，
// 用 [VoiceIdeaControls] 擺（麥克風等在左邊、開始在右邊）。
//
// 需要套件：record（錄音）、audioplayers / path_provider（專案已有）
// ======================================================================

enum _VoiceMode { typing, recording, review }

class VoiceIdeaField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  const VoiceIdeaField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  State<VoiceIdeaField> createState() => VoiceIdeaFieldState();
}

class VoiceIdeaFieldState extends State<VoiceIdeaField>
    with SingleTickerProviderStateMixin {
  static const int _maxSeconds = 60;

  /// 錄音最少要這麼久，太短不收
  static const int minSeconds = 5;

  /// 狀態變了就 +1，外面的 [VoiceIdeaControls] 靠它重畫
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  void _update(VoidCallback fn) {
    setState(fn);
    tick.value++;
  }

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FocusNode _focus = FocusNode();

  late final AnimationController _pulse;

  StreamSubscription<void>? _completeSub;
  Timer? _ticker;

  _VoiceMode _mode = _VoiceMode.typing;
  bool _playing = false;
  int _seconds = 0;
  File? _recording;

  /// 有一段錄好、等著送出的錄音
  bool get hasRecording => _mode == _VoiceMode.review && _recording != null;

  File? get recording => hasRecording ? _recording : null;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _completeSub = _player.onPlayerComplete.listen((_) {
      BgmService.instance.resumeAfterVideo();
      if (mounted) _update(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _completeSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _focus.dispose();
    _pulse.dispose();
    BgmService.instance.unduck();
    BgmService.instance.resumeAfterVideo();
    _deleteRecording();
    super.dispose();
  }

  void _deleteRecording() {
    final File? f = _recording;

    _recording = null;

    if (f != null) {
      f.exists().then((e) {
        if (e) f.delete();
      });
    }
  }

  /// 外面按「開始」前呼叫：停止錄音／播放，並收鍵盤
  /// 回傳 false：還在錄但不到 5 秒，不能送出（錄音繼續）
  Future<bool> stopAll() async {
    _focus.unfocus();

    if (_mode == _VoiceMode.recording) {
      if (_seconds < minSeconds) {
        AppNotice.show('錄音至少要 $minSeconds 秒，請再說一下');
        return false;
      }
      await _stopRecording();
    }

    await _player.stop();
    BgmService.instance.resumeAfterVideo();

    if (mounted) _update(() => _playing = false);
    return true;
  }

  /// 後端轉好文字後呼叫：把文字填進輸入欄，回到手動輸入（可再修改）
  void showTranscript(String text) {
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    _deleteRecording();

    if (mounted) _update(() => _mode = _VoiceMode.typing);
  }

  // ───────────────────────────── 錄音 ─────────────────────────────

  Future<void> _startRecording() async {
    await _player.stop();
    BgmService.instance.resumeAfterVideo();
    if (mounted && _playing) _update(() => _playing = false);

    // 錄音時不需要鍵盤
    FocusManager.instance.primaryFocus?.unfocus();

    bool allowed = false;

    try {
      allowed = await _recorder.hasPermission();
    } catch (_) {}

    if (!allowed) {
      AppNotice.show('沒有麥克風權限，請到手機設定開啟');
      return;
    }

    try {
      final Directory dir = await getTemporaryDirectory();
      final String path =
          '${dir.path}/idea_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // 背景音樂先壓小聲，避免被錄進去
      await BgmService.instance.duck();

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _deleteRecording(); // 重錄：舊的丟掉

      if (!mounted) return;

      _update(() {
        _mode = _VoiceMode.recording;
        _seconds = 0;
        _playing = false;
      });

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;

        _update(() => _seconds++);

        if (_seconds >= _maxSeconds) _stopRecording();
      });
    } catch (e) {
      debugPrint('開始錄音失敗：$e');
      BgmService.instance.unduck();
      AppNotice.show('無法開始錄音，請稍後再試');
    }
  }

  Future<void> _stopRecording() async {
    if (_mode != _VoiceMode.recording) return;

    // 錄音最少 5 秒：還不到就繼續錄（自動停在 60 秒不受影響）
    if (_seconds < minSeconds) {
      AppNotice.show('錄音至少要 $minSeconds 秒，請再說一下');
      return;
    }

    _ticker?.cancel();

    String? path;

    try {
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('停止錄音失敗：$e');
    }

    BgmService.instance.unduck();

    if (!mounted) return;

    if (path == null || _seconds < minSeconds) {
      _update(() => _mode = _VoiceMode.typing);
      AppNotice.show('錄音太短，請再說一次');
      return;
    }

    _update(() {
      _recording = File(path!);
      _mode = _VoiceMode.review;
    });
  }

  /// 錄音中按 ✕：丟掉這次錄音，變回手動輸入
  Future<void> _cancelRecording() async {
    _ticker?.cancel();

    try {
      await _recorder.cancel();
    } catch (_) {}

    BgmService.instance.unduck();

    if (!mounted) return;

    _update(() => _mode = _VoiceMode.typing);
    _focus.requestFocus();
  }

  // ───────────────────────────── 確認 ─────────────────────────────

  /// 播放原本的錄音；播放中再按一次停止。可以重複聽
  Future<void> _togglePlay() async {
    final File? file = _recording;

    if (file == null) return;

    if (_playing) {
      await _player.stop();
      BgmService.instance.resumeAfterVideo();

      if (mounted) _update(() => _playing = false);

      return;
    }

    try {
      // 播放錄音時背景音樂先停掉，播完／停止再恢復
      await BgmService.instance.pauseForVideo();
      await _player.play(DeviceFileSource(file.path));

      if (mounted) _update(() => _playing = true);
    } catch (e) {
      debugPrint('播放錄音失敗：$e');
      BgmService.instance.resumeAfterVideo();
      AppNotice.show('無法播放錄音');
    }
  }

  /// 確認中按 ✕：不要這段錄音了，變回手動輸入
  Future<void> _backToTyping() async {
    await _player.stop();
    BgmService.instance.resumeAfterVideo();

    _deleteRecording();

    if (!mounted) return;

    _update(() {
      _mode = _VoiceMode.typing;
      _playing = false;
    });

    _focus.requestFocus();
  }

  // ───────────────────────────── 畫面 ─────────────────────────────

  String _clock(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bool recording = _mode == _VoiceMode.recording;
    final bool typing = _mode == _VoiceMode.typing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: typing
                    ? TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        textInputAction: TextInputAction.done,
                        maxLines: 1,
                        cursorColor: AppColors.primaryAccent,
                        style: AppTextStyles.bodyEmphasisBold.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: widget.hintText,
                          hintStyle: AppTextStyles.bodyCompact.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          recording
                              ? '錄音中 ${_clock(_seconds)}'
                              : '已錄音 ${_clock(_seconds)}（可重複聽）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyEmphasisBold.copyWith(
                            color: recording
                                ? AppColors.primaryAccent
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        Container(
          height: 1,
          width: double.infinity,
          color: recording ? AppColors.primaryAccent : const Color(0xFF514A44),
        ),
      ],
    );
  }

  /// 錄音的按鈕（依現在的狀態）：給 [VoiceIdeaControls] 擺在「開始」旁邊
  List<Widget> buildActions() {
    switch (_mode) {
      case _VoiceMode.typing:
        return [
          _RoundIcon(
            icon: Icons.mic_rounded,
            tooltip: '語音輸入',
            onTap: _startRecording,
          ),
        ];

      case _VoiceMode.recording:
        return [
          // 錄音中：紅色停止鈕（呼吸動畫）＋ ✕
          ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.08).animate(_pulse),
            child: _RoundIcon(
              icon: Icons.stop_rounded,
              tooltip: '停止錄音',
              filled: true,
              onTap: _stopRecording,
            ),
          ),
          const SizedBox(width: 8),
          _RoundIcon(
            icon: Icons.close_rounded,
            tooltip: '改用手動輸入',
            onTap: _cancelRecording,
          ),
        ];

      case _VoiceMode.review:
        return [
          _RoundIcon(
            icon: _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            tooltip: _playing ? '停止播放' : '聽一遍',
            filled: _playing,
            onTap: _togglePlay,
          ),
          const SizedBox(width: 8),
          _RoundIcon(
            icon: Icons.mic_rounded,
            tooltip: '重新錄音',
            onTap: _startRecording,
          ),
          const SizedBox(width: 8),
          _RoundIcon(
            icon: Icons.close_rounded,
            tooltip: '改用手動輸入',
            onTap: _backToTyping,
          ),
        ];
    }
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : AppColors.warmPaper,
            border: Border.all(color: AppColors.primaryDark, width: 1.4),
          ),
          child: Icon(
            icon,
            size: 22,
            color: filled ? Colors.white : AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

/// 錄音的按鈕們（麥克風／停止／播放／重錄／✕），放在「開始」按鈕的左邊。
/// [fieldKey] 是同一個 [VoiceIdeaField] 的 key，按鈕會跟著它的狀態變
class VoiceIdeaControls extends StatefulWidget {
  final GlobalKey<VoiceIdeaFieldState> fieldKey;

  const VoiceIdeaControls({super.key, required this.fieldKey});

  @override
  State<VoiceIdeaControls> createState() => _VoiceIdeaControlsState();
}

class _VoiceIdeaControlsState extends State<VoiceIdeaControls> {
  VoiceIdeaFieldState? _field;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  // 輸入欄和按鈕同一幀建出來，第一次可能還拿不到輸入欄的狀態，等下一幀再接
  void _bind() {
    final VoiceIdeaFieldState? s = widget.fieldKey.currentState;

    if (s == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bind();
      });
      return;
    }

    _field = s;
    s.tick.addListener(_onChanged);
    setState(() {});
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _field?.tick.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoiceIdeaFieldState? s = _field;

    if (s == null) return const SizedBox(height: 43);

    return SizedBox(
      height: 43,
      child: Row(mainAxisSize: MainAxisSize.min, children: s.buildActions()),
    );
  }
}
