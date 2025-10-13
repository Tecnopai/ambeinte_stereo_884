import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:volume_controller/volume_controller.dart';

/// Clase global para manejar el reproductor de audio con just_audio
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  AudioPlayer? _audioPlayer;
  VolumeController?
  _systemVolumeController; // ✅ Renombrado para evitar conflicto

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userStoppedManually = false;
  double _volume = 0.7;

  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';
  static const String radioName = 'Ambiente Stereo 88.4 FM';

  // Configuración de reconexión
  static const int _maxRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(seconds: 30);
  int _retryCount = 0;
  int _consecutiveErrors = 0;
  Timer? _retryTimer;
  Timer? _healthCheckTimer;
  Timer? _connectivityCheckTimer;

  bool _isRestarting = false;
  StreamSubscription? _playerStateSubscription;

  // Stream controllers
  final _playingController = StreamController<bool>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _volumeStreamController =
      StreamController<double>.broadcast(); // ✅ Renombrado
  final _errorController = StreamController<String>.broadcast();

  // Getters
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<double> get volumeStream =>
      _volumeStreamController.stream; // ✅ Actualizado
  Stream<String> get errorStream => _errorController.stream;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  /// Inicializa el sistema
  Future<void> init() async {
    try {
      await _initializeVolumeController();
      _initializePlayer();
      _log('✅ AudioPlayerManager inicializado correctamente');
    } catch (e) {
      _log('❌ Error al inicializar: $e');
    }
  }

  /// Inicializa el controlador de volumen del sistema
  Future<void> _initializeVolumeController() async {
    try {
      _systemVolumeController = VolumeController(); // ✅ Actualizado

      // Obtener volumen actual del sistema
      final systemVolume = await _systemVolumeController!.getVolume();
      _volume = systemVolume;
      _volumeStreamController.add(_volume); // ✅ Actualizado

      _log('🔊 Volumen inicial del sistema: ${(_volume * 100).round()}%');

      // Escuchar cambios en los botones físicos
      _systemVolumeController!.listener((newVolume) {
        // ✅ Actualizado
        _log(
          '🔊 Botón físico detectado - Nuevo volumen: ${(newVolume * 100).round()}%',
        );
        _volume = newVolume;
        _volumeStreamController.add(_volume); // ✅ Actualizado

        // Sincronizar con el player
        _audioPlayer?.setVolume(_volume);
      });

      _log('✅ VolumeController inicializado');
    } catch (e) {
      _log('❌ Error al inicializar VolumeController: $e');
      // Si falla, usar volumen por defecto
      _volume = 0.7;
      _volumeStreamController.add(_volume); // ✅ Actualizado
    }
  }

  /// Inicializa el reproductor
  void _initializePlayer() {
    try {
      _audioPlayer = AudioPlayer();

      // Escuchar estados del player
      _playerStateSubscription = _audioPlayer!.playerStateStream.listen(
        (state) {
          _log(
            'Estado: ${state.playing ? "playing" : "paused"}, processingState: ${state.processingState}',
          );

          final wasPlaying = _isPlaying;
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;

          if (_isPlaying) {
            _retryCount = 0;
            _consecutiveErrors = 0;
            _errorController.add('');
            _startHealthCheck();
            _startConnectivityCheck();
          } else {
            if (wasPlaying && !_userStoppedManually && !_isRestarting) {
              _log('⚠️ Stream se detuvo inesperadamente');
              _consecutiveErrors++;
              _scheduleReconnect();
            }
          }

          _playingController.add(_isPlaying);
          _loadingController.add(_isLoading);
        },
        onError: (error) {
          _log('❌ Error en playerStateStream: $error');
          _consecutiveErrors++;
          _handlePlayerError(error);
        },
      );

      // Escuchar errores de playback
      _audioPlayer!.playbackEventStream.listen(
        (event) {
          _log(
            'Playback event - state: ${event.processingState}, buffered: ${event.bufferedPosition}',
          );
        },
        onError: (error) {
          _log('❌ Error en playback: $error');
          _handlePlayerError(error);
        },
      );

      // Aplicar el volumen inicial del sistema
      _audioPlayer!.setVolume(_volume);

      _log(
        '✅ AudioPlayer inicializado con volumen ${(_volume * 100).round()}%',
      );
    } catch (e) {
      _log('❌ Error al inicializar player: $e');
    }
  }

  /// Alterna playback
  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await stop();
    } else {
      await play();
    }
  }

  /// Inicia reproducción
  Future<void> play() async {
    if (_isRestarting) {
      _log('⚠️ Reinicio en curso');
      return;
    }

    try {
      _userStoppedManually = false;
      _isLoading = true;
      _loadingController.add(_isLoading);

      final hasConnection = await _checkRealConnectivity();

      if (!hasConnection) {
        _log('❌ Sin conexión');
        _isLoading = false;
        _isPlaying = false;
        _loadingController.add(_isLoading);
        _playingController.add(_isPlaying);
        _errorController.add('Sin conexión. Reintentando...');
        _scheduleReconnect();
        return;
      }

      _log('✅ Configurando URL del stream...');

      if (_consecutiveErrors > 3) {
        await _forceRestart();
        return;
      }

      await _audioPlayer?.setUrl(streamUrl);
      _log('✅ URL configurada, iniciando play()...');

      await _audioPlayer?.play();
      _log('✅ play() llamado, esperando respuesta del player...');

      _retryCount = 0;
    } catch (e) {
      _log('❌ Error al reproducir: $e');
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Error al conectar. Reintentando...');
      _scheduleReconnect();
    }
  }

  /// Detiene reproducción
  Future<void> stop() async {
    try {
      _userStoppedManually = true;
      _isRestarting = false;
      _cancelReconnect();
      _stopHealthCheck();
      _stopConnectivityCheck();

      await _audioPlayer?.stop();

      _isPlaying = false;
      _isLoading = false;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);

      _log('Detenido por usuario');
    } catch (e) {
      _log('❌ Error en stop: $e');
      _isPlaying = false;
      _isLoading = false;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);
    }
  }

  /// Reinicio forzado
  Future<void> _forceRestart() async {
    if (_isRestarting) return;

    _log('🔄 Reinicio forzado');
    _isRestarting = true;

    try {
      _cancelReconnect();
      _stopHealthCheck();
      _stopConnectivityCheck();

      _isLoading = true;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Reiniciando...');

      await _audioPlayer?.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      _consecutiveErrors = 0;

      if (_userStoppedManually) {
        _isRestarting = false;
        _isLoading = false;
        _loadingController.add(_isLoading);
        return;
      }

      final hasConnection = await _checkRealConnectivity();

      if (!hasConnection) {
        _isRestarting = false;
        _isLoading = false;
        _loadingController.add(_isLoading);
        _errorController.add('Sin conexión. Reintentando...');
        _scheduleReconnect();
        return;
      }

      await _audioPlayer?.setUrl(streamUrl);
      await _audioPlayer?.play();

      _log('✅ Reinicio exitoso');
      _errorController.add('');
    } catch (e) {
      _log('❌ Error en reinicio: $e');
      _isLoading = false;
      _loadingController.add(_isLoading);
      _errorController.add('Error. Reintentando...');
      _scheduleReconnect();
    } finally {
      _isRestarting = false;
      _isLoading = false;
      _loadingController.add(_isLoading);
    }
  }

  /// Verifica conectividad
  Future<bool> _checkRealConnectivity() async {
    try {
      final response = await http
          .head(Uri.parse(streamUrl))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 301 ||
          response.statusCode == 403 ||
          response.statusCode == 400;
    } catch (e) {
      return false;
    }
  }

  void _startConnectivityCheck() {
    _stopConnectivityCheck();

    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 15), (
      timer,
    ) async {
      if (_isPlaying &&
          !_userStoppedManually &&
          !_isLoading &&
          !_isRestarting) {
        final hasConnection = await _checkRealConnectivity();

        if (!hasConnection) {
          _log('⚠️ Conectividad perdida');
          _isPlaying = false;
          _playingController.add(_isPlaying);
          _errorController.add('Sin conexión');
          _scheduleReconnect();
        }
      }
    });
  }

  void _stopConnectivityCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = null;
  }

  void _handlePlayerError(dynamic error) {
    if (_isRestarting) return;

    _log('⚠️ Error: $error');

    _isLoading = false;
    _isPlaying = false;
    _loadingController.add(_isLoading);
    _playingController.add(_isPlaying);

    if (!_userStoppedManually) {
      if (_consecutiveErrors > 5) {
        _errorController.add('Reiniciando...');
        _forceRestart();
      } else {
        _errorController.add('Reintentando...');
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_isRestarting) return;

    _cancelReconnect();

    if (_retryCount >= _maxRetries) {
      _errorController.add('Reintentando en ${_maxRetryDelay.inSeconds}s...');
      _retryTimer = Timer(_maxRetryDelay, () {
        _retryCount = 0;
        _attemptReconnect();
      });
      return;
    }

    final delay = Duration(
      seconds: (_initialRetryDelay.inSeconds * (1 << _retryCount)).clamp(
        2,
        _maxRetryDelay.inSeconds,
      ),
    );

    _retryTimer = Timer(delay, _attemptReconnect);
  }

  Future<void> _attemptReconnect() async {
    if (_userStoppedManually || _isRestarting) return;

    _retryCount++;
    _log('Reconexión #$_retryCount');

    final hasConnection = await _checkRealConnectivity();

    if (!hasConnection) {
      _errorController.add('Sin conexión. Reintentando...');
      _scheduleReconnect();
      return;
    }

    if (_consecutiveErrors > 5) {
      await _forceRestart();
      return;
    }

    _isLoading = true;
    _loadingController.add(_isLoading);

    try {
      await _audioPlayer?.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      await _audioPlayer?.setUrl(streamUrl);
      await _audioPlayer?.play();

      _log('✅ Reconexión exitosa');
      _errorController.add('Reconectado');
    } catch (e) {
      _log('❌ Error reconexión: $e');
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _scheduleReconnect();
    }
  }

  void _cancelReconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _startHealthCheck() {
    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isPlaying && !_userStoppedManually && !_isRestarting) {
        _log('Health check: OK');
      }
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Establece el volumen (tanto en el player como en el sistema)
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);

      // Aplicar al player de audio
      await _audioPlayer?.setVolume(_volume);

      // Sincronizar con el volumen del sistema (no es async)
      _systemVolumeController?.setVolume(_volume); // ✅ Sin await

      // Emitir al stream
      _volumeStreamController.add(_volume);

      _log('🔊 Volumen establecido: ${(_volume * 100).round()}%');
    } catch (e) {
      _log('❌ Error al establecer volumen: $e');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[AudioPlayerManager] $message');
    }
  }

  void dispose() {
    _isRestarting = false;
    _cancelReconnect();
    _stopHealthCheck();
    _stopConnectivityCheck();

    _playerStateSubscription?.cancel();

    _playingController.close();
    _loadingController.close();
    _volumeStreamController.close(); // ✅ Actualizado
    _errorController.close();

    _audioPlayer?.dispose();
    _systemVolumeController?.removeListener(); // ✅ Actualizado
  }
}
