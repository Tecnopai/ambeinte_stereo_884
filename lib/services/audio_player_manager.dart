import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Clase global para manejar el reproductor de audio
/// Implementa el patrón Singleton para mantener una única instancia
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  double _volume = 0.7; // Volumen inicial al 70%
  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';

  // Stream controllers para notificar cambios
  final _playingController = StreamController<bool>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _volumeController = StreamController<double>.broadcast();

  // Getters para los streams
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<double> get volumeStream => _volumeController.stream;

  // Getters para el estado actual
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  /// Inicializa el reproductor de audio
  void init() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _isPlaying = state == PlayerState.playing;
      _isLoading = false;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);
    });

    // Establecer volumen inicial
    _audioPlayer.setVolume(_volume);
  }

  /// Alterna entre reproducir y pausar
  Future<void> togglePlayback() async {
    _isLoading = true;
    _loadingController.add(_isLoading);

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
      } else {
        await _audioPlayer.play(UrlSource(streamUrl));
      }
    } catch (e) {
      _isLoading = false;
      _loadingController.add(_isLoading);
      rethrow;
    }
  }

  /// Establece el volumen del reproductor
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    _volumeController.add(_volume);
  }

  /// Libera los recursos del reproductor
  void dispose() {
    _audioPlayer.dispose();
    _playingController.close();
    _loadingController.close();
    _volumeController.close();
  }
}
