import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

enum BgmTrack { login, main }

class BgmService with WidgetsBindingObserver {
  BgmService._();
  static final BgmService instance = BgmService._();

  final AudioPlayer _player = AudioPlayer();

  static const Map<BgmTrack, String> _paths = {
    BgmTrack.login: 'audio/login_music.mp3',
    BgmTrack.main: 'audio/music.mp3',
  };

  BgmTrack? _current;
  bool _muted = false;
  bool get muted => _muted;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _player.setReleaseMode(ReleaseMode.loop); // 循環播放
    await _player.setVolume(0.35);
  }

  Future<void> play(BgmTrack track) async {
    if (_current == track) return;
    _current = track;
    await _player.stop();
    if (_muted) return;
    await _player.play(AssetSource(_paths[track]!));
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
    if (_current == null || _muted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed) {
      _player.resume();
    }
  }
}
