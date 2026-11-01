import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../block/script_generating_overlay.dart';
import 'app_notice.dart';
import 'auth_guard.dart';

/// 全域的「劇本生成中」狀態：生成不綁在某一頁上，玩家可以先回首頁，
/// 之後點旁邊的圓形按鈕再看 loading 彈窗；生成完成後由發起的那一頁跳轉。
class StoryGeneration extends ChangeNotifier {
  StoryGeneration._();

  static final StoryGeneration instance = StoryGeneration._();

  /// 沒有真的進度時（遊你說了算）假的進度條走完要多久，沒好就停在 97%
  static const Duration fakeDuration = Duration(minutes: 5);

  bool active = false;
  bool cancelled = false;
  bool overlayVisible = false;
  double progress = 0;
  String text = '';
  String? jobId;

  /// 這次生成的縣市、行政區（有的話）：逛逛商家頁會自動帶入
  String? city;
  String? town;

  int _run = 0;
  double _target = 0;
  bool _fake = false;
  bool _finishing = false;
  DateTime _startAt = DateTime.now();
  Timer? _ticker;
  Future<void> Function(String jobId)? _cancelApi;

  /// 開始一次生成，回傳這一次的代號；之後用 [isCurrent] 確認還是不是同一次（被取消或換成別次就不是）
  int start({
    required String text,
    required Future<void> Function(String jobId) cancelApi,
    bool fake = false,
    String? city,
    String? town,
  }) {
    _ticker?.cancel();
    _run++;
    active = true;
    cancelled = false;
    overlayVisible = true;
    _finishing = false;
    _fake = fake;
    _startAt = DateTime.now();
    _cancelApi = cancelApi;
    jobId = null;
    this.city = city;
    this.town = town;
    progress = 0.01;
    _target = 0.01;
    this.text = text;
    _ticker = Timer.periodic(const Duration(milliseconds: 50), _tick);
    notifyListeners();
    return _run;
  }

  bool isCurrent(int run) => run == _run && active && !cancelled;

  void _tick(Timer timer) {
    if (!active) {
      timer.cancel();
      return;
    }

    if (_fake && !_finishing) {
      final double s =
          DateTime.now().difference(_startAt).inMilliseconds /
          fakeDuration.inMilliseconds;
      _target = (0.01 + 0.96 * s).clamp(0.01, 0.97);
    }

    final double goal = _target.clamp(0.0, _finishing ? 1.0 : 0.97);

    if (goal > progress) {
      // 慢慢靠過去，不要一下子跳過去
      final double rate = _finishing ? 0.25 : 0.08;
      final double step = ((goal - progress) * rate).clamp(0.0015, 1.0);
      progress = (progress + step).clamp(0.0, goal);
      notifyListeners();
    }
  }

  /// 後端給的真實進度（0～1）；只會往前
  void setTarget(double value) {
    if (!_finishing && value > _target) _target = value.clamp(0.0, 0.97);
  }

  void setText(String value) {
    if (value.isEmpty || value == text) return;
    text = value;
    notifyListeners();
  }

  void setJobId(String id) {
    jobId = id;
    if (cancelled) _cancelApi?.call(id).catchError((_) {});
  }

  /// 做好了：進度條快速跑到 100% 再回來
  Future<void> complete() async {
    _finishing = true;
    _target = 1.0;
    text = '劇本生成完成';
    notifyListeners();

    final DateTime end = DateTime.now().add(const Duration(milliseconds: 1500));

    while (progress < 0.999 && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    progress = 1;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void finish() {
    _ticker?.cancel();
    active = false;
    overlayVisible = false;
    _finishing = false;
    notifyListeners();
  }

  void cancel() {
    if (!active) return;

    cancelled = true;
    final String? id = jobId;
    if (id != null) _cancelApi?.call(id).catchError((_) {});

    finish();
    AppNotice.show('已取消生成');
  }

  void showOverlay() {
    overlayVisible = true;
    notifyListeners();
  }

  void goHome() {
    overlayVisible = false;
    notifyListeners();
    AuthGuard.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }
}

/// 放在 MaterialApp.builder：生成中顯示 loading 彈窗；按「回首頁」或點黑色區塊後，縮成貼在畫面右邊中間的圓形進度鈕。
/// 圓形鈕可以長按拖曳放到喜歡的位置，第一次出現時會先提醒
class GenerationLayer extends StatefulWidget {
  const GenerationLayer({super.key});

  @override
  State<GenerationLayer> createState() => _GenerationLayerState();
}

class _GenerationLayerState extends State<GenerationLayer> {
  static const double _size = 56;
  static const String _hintKey = 'gen_bubble_hint_shown';

  // 拖曳過的位置（左上角）；null 表示還在預設的「右邊中間」
  static Offset? _pos;

  bool _dragging = false;
  bool _hintChecked = false;

  Future<void> _showHintOnce() async {
    if (_hintChecked) return;
    _hintChecked = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(_hintKey) == true) return;

      await prefs.setBool(_hintKey, true);
      AppNotice.show('劇本在背景生成中！長按圓形按鈕可以拖曳，放到喜歡的位置');
    } catch (_) {}
  }

  Offset _clamp(Offset o, Size size, EdgeInsets pad) {
    return Offset(
      o.dx.clamp(0.0, size.width - _size),
      o.dy.clamp(pad.top, size.height - _size - pad.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StoryGeneration.instance,
      builder: (context, _) {
        final StoryGeneration g = StoryGeneration.instance;

        if (!g.active) {
          _hintChecked = false;
          return const SizedBox.shrink();
        }

        if (g.overlayVisible) {
          return Positioned.fill(
            child: ScriptGeneratingOverlay(
              message: g.text,
              progress: g.progress,
              detail: '${(g.progress * 100).round()}%',
              stage: g.progress < 0.3 ? 0 : 1,
              onCancel: g.cancel,
              onHome: g.goHome,
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _showHintOnce());

        final MediaQueryData mq = MediaQuery.of(context);
        final Size size = mq.size;
        final Offset pos = _clamp(
          _pos ?? Offset(size.width - _size - 4, (size.height - _size) / 2),
          size,
          mq.padding,
        );

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: g.showOverlay,
            onLongPressStart: (_) {
              HapticFeedback.mediumImpact();
              setState(() => _dragging = true);
            },
            onLongPressMoveUpdate: (d) {
              setState(() {
                _pos = _clamp(
                  d.globalPosition - const Offset(_size / 2, _size / 2),
                  size,
                  mq.padding,
                );
              });
            },
            onLongPressEnd: (_) => setState(() => _dragging = false),
            child: AnimatedScale(
              scale: _dragging ? 1.15 : 1,
              duration: const Duration(milliseconds: 120),
              child: Material(
                color: Colors.white,
                elevation: _dragging ? 12 : 6,
                shape: const CircleBorder(),
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: g.progress,
                          strokeWidth: 4,
                          backgroundColor: const Color(0xFFE6DCCB),
                          color: const Color(0xFFB5493A),
                        ),
                      ),
                      Text(
                        '${(g.progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF40342D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
