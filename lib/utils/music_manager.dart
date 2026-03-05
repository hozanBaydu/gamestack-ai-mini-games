import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class MusicManager {

  static final MusicManager _instance = MusicManager._internal();
  static MusicManager get instance => _instance;

  MusicManager._internal();

  final AudioPlayer _player = AudioPlayer();
  int? _currentMusicId;
  bool _isPlaying = false;
  double _volume = 0.5;

  final ValueNotifier<bool> isMutedNotifier = ValueNotifier(false);

  void toggleMute() {
    isMutedNotifier.value = !isMutedNotifier.value;
    if (isMutedNotifier.value) {
      _player.setVolume(0);
    } else {
      _player.setVolume(_volume);
    }
  }

  Timer? _debounceTimer;

  Future<void> playMusic(int? musicId) async {

    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        _playMusicInternal(musicId);
    });
  }

  Future<void> _playMusicInternal(int? musicId) async {

    if (musicId == null || musicId == 0) {
      await stopMusic();
      return;
    }

    if (_currentMusicId == musicId && _isPlaying) {
      return;
    }

    try {

      await _player.stop();

      _currentMusicId = musicId;
      _isPlaying = true;

      await _player.setVolume(isMutedNotifier.value ? 0 : _volume);

      await _player.setReleaseMode(ReleaseMode.loop);

      await _player.play(AssetSource('audio/$musicId.ogg'));

      debugPrint('MusicManager: Playing audio/$musicId.ogg');
    } catch (e) {
      debugPrint('MusicManager Error: Could not play music $musicId. Error: $e');
      _isPlaying = false;
    }
  }

  Future<void> stopMusic() async {
    await _player.stop();
    _isPlaying = false;
    _currentMusicId = null;
    debugPrint('MusicManager: Music stopped.');
  }

  Future<void> pauseMusic() async {
    if (_isPlaying) {
      await _player.pause();
      _isPlaying = false;
      debugPrint('MusicManager: Music paused.');
    }
  }

  Future<void> resumeMusic() async {

    if (_currentMusicId != null && !_isPlaying) {

        await _player.resume();
        _isPlaying = true;

        await _player.setVolume(isMutedNotifier.value ? 0 : _volume);

        debugPrint('MusicManager: Music resumed.');
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    if (!isMutedNotifier.value) {
      await _player.setVolume(_volume);
    }
  }

  void dispose() {
    _player.dispose();
    isMutedNotifier.dispose();
  }
}

