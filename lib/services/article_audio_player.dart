import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class ArticleAudioPlayer {
  AudioPlayer? _audioPlayer;
  String? _currentUrl;

  Future<void> play(String url) async {
    try {
      // Usando null-aware assignment en lugar de if statement
      _audioPlayer ??= AudioPlayer();

      if (_currentUrl != url) {
        await _audioPlayer!.stop();
        await _audioPlayer!.setUrl(url);
        _currentUrl = url;
      }

      await _audioPlayer!.play();
    } catch (e) {
      // En lugar de print, puedes usar debugPrint o un logger
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pause() async {
    await _audioPlayer?.pause();
  }

  Future<void> stop() async {
    await _audioPlayer?.stop();
    _currentUrl = null;
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _currentUrl = null;
  }
}
