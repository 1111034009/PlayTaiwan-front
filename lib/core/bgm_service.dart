import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BgmTrack { login, main }

class BgmService with WidgetsBindingObserver {
  BgmService._();
  static final BgmService instance = BgmService._();

  static const String _volumeKey = 'bgm_volume';

  final AudioPlayer _player = AudioPlayer();
  double _volume = 0.5;
  static const double _duckVolume = 0.12;
  bool _videoPlaying = false;

  double get volume => _volume;

  Future<void> duck() => _player.setVolume(_duckVolume);

  Future<void> unduck() => _player.setVolume(_volume);

  // 拉桿拖動時即時調整音量（不寫入）
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  // 放開拉桿時才存起來
  Future<void> saveVolume() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  static const Map<BgmTrack, String> _paths = {
    BgmTrack.login: 'audio/login_music.mp3',
    BgmTrack.main: 'audio/music.mp3',
  };

  BgmTrack? _current;
  bool _muted = false;
  bool get muted => _muted;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_volumeKey) ?? 0.5;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_volume);
  }

  Future<void> play(BgmTrack track) async {
    if (_current == track) return;
    _current = track;
    await _player.stop();
    if (_muted || _videoPlaying) return;
    await _player.play(AssetSource(_paths[track]!));
  }

  // 影片開始播放：背景音樂暫停
  Future<void> pauseForVideo() async {
    _videoPlaying = true;
    if (_current == null || _muted) return;
    await _player.pause();
  }

  // 影片結束／暫停／離開頁面：背景音樂恢復
  Future<void> resumeAfterVideo() async {
    _videoPlaying = false;
    if (_current == null || _muted) return;
    if (_player.state == PlayerState.paused) {
      await _player.resume();
    } else if (_player.state != PlayerState.playing) {
      await _player.play(AssetSource(_paths[_current!]!));
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      await _player.pause();
    } else if (_current != null) {
      final BgmTrack track = _current!;
      _current = null; // 讓 play() 重新載入
      await play(track);
    }
  }

  // App 進背景暫停，回前景繼續
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_current == null || _muted || _videoPlaying) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed) {
      _player.resume();
    }
  }
}
