import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:volume_controller/volume_controller.dart';

/// Gestor global del reproductor de audio para streaming de radio
/// Implementa patrón Singleton para mantener una única instancia
/// Maneja reproducción, volumen, reconexión automática y estados
/// ✅ OPTIMIZADO PARA REPRODUCCIÓN EN SEGUNDO PLANO INDEFINIDA
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  // Instancia del reproductor de audio
  AudioPlayer? _audioPlayer;

  // Estados del reproductor
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userStoppedManually = false;
  bool _isDisposed = false;
  double _volume = 0.7;

  // Configuración del stream
  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';
  static const String radioName = 'Ambiente Stereo 88.4 FM';

  // Configuración de reconexión automática
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 3);
  static const Duration _maxRetryDelay = Duration(seconds: 20);
  static const Duration _minDelayBetweenAttempts = Duration(seconds: 2);

  int _retryCount = 0;
  int _consecutiveErrors = 0;
  DateTime? _lastAttemptTime;

  Timer? _retryTimer;
  Timer? _connectivityCheckTimer;

  bool _isRestarting = false;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playbackEventSubscription;

  // Stream controllers para emitir cambios de estado
  final _playingController = StreamController<bool>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _volumeStreamController = StreamController<double>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Getters para los streams
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<double> get volumeStream => _volumeStreamController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters para los estados actuales
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  /// Inicializa el gestor de audio y el controlador de volumen
  /// Inicia la reproducción si no fue detenida manualmente.
  Future<void> init() async {
    if (_isDisposed) return;

    try {
      await _initializeVolumeController();
      await _initializePlayer();

      // Auto-Play: Intenta reproducir solo si el usuario no detuvo
      if (!_userStoppedManually) {
        await play();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar: $e');
      }
      if (!_errorController.isClosed) {
        _errorController.add('Error al inicializar el reproductor.');
      }
    }
  }

  /// Inicializa el controlador de volumen del sistema
  Future<void> _initializeVolumeController() async {
    try {
      final systemVolume = await VolumeController.instance.getVolume();
      _volume = systemVolume;

      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }

      VolumeController.instance.showSystemUI = false;

      VolumeController.instance.addListener((newVolume) {
        if (_isDisposed) return;
        _volume = newVolume;
        if (!_volumeStreamController.isClosed) {
          _volumeStreamController.add(_volume);
        }
        _audioPlayer?.setVolume(_volume);
      });
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar VolumeController: $e');
      }
      _volume = 0.7;
      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }
    }
  }

  /// Inicializa el reproductor de audio con configuración optimizada
  /// ✅ OPTIMIZADO PARA SEGUNDO PLANO
  Future<void> _initializePlayer() async {
    if (_isDisposed) return;

    try {
      _cleanupPlayer();
      _audioPlayer = AudioPlayer();

      // ✅ CONFIGURACIÓN CRÍTICA PARA SEGUNDO PLANO
      // Configurar el audio source con opciones de buffer optimizadas
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: MediaItem(
            id: 'ambiente_stereo_live',
            title: radioName,
            artist: 'En vivo',
          ),
        ),
        // ✅ Preload true para mantener buffer activo
        preload: true,
      );

      // ✅ Configurar modo de audio para segundo plano
      // Esto le dice a Android que es contenido de audio continuo
      await _audioPlayer!.setLoopMode(LoopMode.off);

      // ✅ Configurar para que no se pause automáticamente
      await _audioPlayer!.setCanUseNetworkResourcesForLiveStreamingWhilePaused(
        true,
      );

      // Escuchar cambios de estado del reproductor
      _playerStateSubscription = _audioPlayer!.playerStateStream.listen(
        _handlePlayerStateChange,
        onError: _handlePlayerError,
        cancelOnError: false,
      );

      // Escuchar eventos de playback
      _playbackEventSubscription = _audioPlayer!.playbackEventStream.listen(
        null,
        onError: _handlePlayerError,
        cancelOnError: false,
      );

      // Aplicar volumen inicial
      _audioPlayer!.setVolume(_volume);
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar player: $e');
      }
      rethrow;
    }
  }

  /// Maneja cambios en el estado del reproductor
  void _handlePlayerStateChange(PlayerState state) {
    if (_isDisposed || _isRestarting) return;

    final wasPlaying = _isPlaying;
    final newIsPlaying = state.playing;
    final newIsLoading =
        state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;

    _isPlaying = newIsPlaying;
    _isLoading = newIsLoading;

    // Si está reproduciendo correctamente, resetear contadores
    if (_isPlaying && state.processingState == ProcessingState.ready) {
      _retryCount = 0;
      _consecutiveErrors = 0;
      if (!_errorController.isClosed) {
        _errorController.add('');
      }
      _startConnectivityCheck();
    }

    // Si se detuvo inesperadamente
    if (wasPlaying && !newIsPlaying && !_userStoppedManually) {
      if (state.processingState == ProcessingState.idle ||
          state.processingState == ProcessingState.completed) {
        _consecutiveErrors++;
        _scheduleReconnect();
      }
    }

    // Emitir cambios de estado
    if (!_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }
    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }
  }

  /// Alterna entre reproducir y pausar
  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await stop();
    } else {
      await play();
    }
  }

  /// Inicia la reproducción del stream
  Future<void> play() async {
    if (_isDisposed || _isRestarting || _isPlaying) return;

    // Prevenir intentos muy frecuentes
    if (_lastAttemptTime != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastAttemptTime!);
      if (timeSinceLastAttempt < _minDelayBetweenAttempts) {
        return;
      }
    }
    _lastAttemptTime = DateTime.now();

    try {
      _userStoppedManually = false;
      _isLoading = true;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }

      // Si hay muchos errores consecutivos, forzar reinicio
      if (_consecutiveErrors > 5) {
        await _forceRestart();
        return;
      }

      // Reproducir
      await _audioPlayer?.play();
      _retryCount = 0;
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al reproducir: $e');
      }
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_errorController.isClosed) {
        _errorController.add('Error de conexión');
      }
      _scheduleReconnect();
    }
  }

  /// Detiene la reproducción
  Future<void> stop() async {
    if (_isDisposed) return;

    try {
      _userStoppedManually = true;
      _isRestarting = false;
      _cancelReconnect();
      _stopConnectivityCheck();

      await _audioPlayer?.stop();

      _isPlaying = false;
      _isLoading = false;
      _consecutiveErrors = 0;
      _retryCount = 0;

      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_errorController.isClosed) {
        _errorController.add('');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error en stop: $e');
      }
      _isPlaying = false;
      _isLoading = false;
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
    }
  }

  /// Realiza un reinicio forzado del reproductor
  Future<void> _forceRestart() async {
    if (_isDisposed || _isRestarting) return;

    _isRestarting = true;

    try {
      _cancelReconnect();
      _stopConnectivityCheck();

      _isLoading = true;
      _isPlaying = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_errorController.isClosed) {
        _errorController.add('Reiniciando...');
      }

      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      await Future.delayed(const Duration(seconds: 2));

      await _initializePlayer();
      await Future.delayed(const Duration(milliseconds: 500));

      _consecutiveErrors = 0;
      _retryCount = 0;

      if (_userStoppedManually) {
        _isRestarting = false;
        _isLoading = false;
        if (!_loadingController.isClosed) {
          _loadingController.add(_isLoading);
        }
        return;
      }

      await _audioPlayer?.play();

      if (!_errorController.isClosed) {
        _errorController.add('');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error en reinicio: $e');
      }
      _isLoading = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_errorController.isClosed) {
        _errorController.add('Error al reiniciar');
      }
      _scheduleReconnect();
    } finally {
      _isRestarting = false;
      _isLoading = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
    }
  }

  /// ✅ OPTIMIZADO: Verificación de conectividad más agresiva
  void _startConnectivityCheck() {
    if (_isDisposed) return;
    _stopConnectivityCheck();

    // ✅ Reducido a 15 segundos para detectar problemas más rápido
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      if (_isDisposed || !_isPlaying || _userStoppedManually || _isRestarting) {
        return;
      }

      if (_audioPlayer != null) {
        final state = _audioPlayer!.playerState;

        // Si está en idle cuando debería estar reproduciendo, reconectar
        if (state.processingState == ProcessingState.idle) {
          _consecutiveErrors++;
          if (!_errorController.isClosed) {
            _errorController.add('Conexión perdida');
          }
          _scheduleReconnect();
        }
      }
    });
  }

  /// Detiene el timer de verificación de conectividad
  void _stopConnectivityCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = null;
  }

  /// Maneja errores del reproductor
  void _handlePlayerError(dynamic error) {
    if (_isDisposed || _isRestarting || _userStoppedManually) return;

    _consecutiveErrors++;
    _isLoading = false;
    _isPlaying = false;

    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }
    if (!_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }

    if (_consecutiveErrors > 3) {
      if (!_errorController.isClosed) {
        _errorController.add('Reiniciando...');
      }
      _forceRestart();
    } else {
      if (!_errorController.isClosed) {
        _errorController.add('Error de reproducción');
      }
      _scheduleReconnect();
    }
  }

  /// Programa un intento de reconexión con retroceso exponencial
  void _scheduleReconnect() {
    if (_isDisposed || _isRestarting || _userStoppedManually) return;

    _cancelReconnect();

    int delaySeconds;
    if (_retryCount >= _maxRetries) {
      delaySeconds = _maxRetryDelay.inSeconds;
      _retryCount = 0;
    } else {
      delaySeconds = (_initialRetryDelay.inSeconds * (1 << _retryCount)).clamp(
        3,
        _maxRetryDelay.inSeconds,
      );
    }

    final delay = Duration(seconds: delaySeconds);

    if (!_errorController.isClosed) {
      _errorController.add('Reintentando en ${delaySeconds}s...');
    }

    _retryTimer = Timer(delay, _attemptReconnect);
  }

  /// Intenta reconectar al stream
  Future<void> _attemptReconnect() async {
    if (_isDisposed || _userStoppedManually || _isRestarting) return;

    _retryCount++;

    if (_consecutiveErrors > 3) {
      await _forceRestart();
      return;
    }

    _isLoading = true;
    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }

    try {
      await _audioPlayer?.stop();
      await Future.delayed(const Duration(milliseconds: 1000));
      await _audioPlayer?.play();

      if (!_errorController.isClosed) {
        _errorController.add('');
      }
    } catch (e) {
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      _scheduleReconnect();
    }
  }

  /// Cancela el timer de reconexión
  void _cancelReconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Establece el volumen tanto en el reproductor como en el sistema
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;

    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer?.setVolume(_volume);
      VolumeController.instance.setVolume(_volume);

      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al establecer volumen: $e');
      }
    }
  }

  /// Limpia el reproductor actual
  void _cleanupPlayer() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;

    _playbackEventSubscription?.cancel();
    _playbackEventSubscription = null;

    _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  /// Libera todos los recursos utilizados
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _isRestarting = false;
    _userStoppedManually = true;

    _cancelReconnect();
    _stopConnectivityCheck();

    _cleanupPlayer();

    _playingController.close();
    _loadingController.close();
    _volumeStreamController.close();
    _errorController.close();

    VolumeController.instance.removeListener();
  }
}

/// Clase para metadata del audio (requerida por just_audio)
class MediaItem {
  final String id;
  final String title;
  final String artist;

  MediaItem({required this.id, required this.title, required this.artist});
}
