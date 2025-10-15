import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:volume_controller/volume_controller.dart';

/// Gestor global del reproductor de audio para streaming de radio
/// Implementa patrón Singleton para mantener una única instancia
/// Maneja reproducción, volumen, reconexión automática y estados
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
  double _volume = 0.7;

  // Configuración del stream
  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';
  static const String radioName = 'Ambiente Stereo 88.4 FM';

  // Configuración de reconexión automática
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
  Future<void> init() async {
    try {
      await _initializeVolumeController();
      _initializePlayer();
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar: $e');
      }
    }
  }

  /// Inicializa el controlador de volumen del sistema
  /// Sincroniza el volumen con los botones físicos del dispositivo
  Future<void> _initializeVolumeController() async {
    try {
      // Obtener volumen actual del sistema
      final systemVolume = await VolumeController.instance.getVolume();
      _volume = systemVolume;

      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }

      // Configurar para no mostrar UI del sistema
      VolumeController.instance.showSystemUI = false;

      // Escuchar cambios en los botones físicos de volumen
      VolumeController.instance.addListener((newVolume) {
        _volume = newVolume;

        if (!_volumeStreamController.isClosed) {
          _volumeStreamController.add(_volume);
        }

        // Sincronizar con el reproductor
        _audioPlayer?.setVolume(_volume);
      });
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar VolumeController: $e');
      }
      // Si falla, usar volumen por defecto
      _volume = 0.7;
      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }
    }
  }

  /// Inicializa el reproductor de audio y configura los listeners
  void _initializePlayer() {
    try {
      _audioPlayer = AudioPlayer();

      // Escuchar cambios de estado del reproductor
      _playerStateSubscription = _audioPlayer!.playerStateStream.listen(
        (state) {
          final wasPlaying = _isPlaying;
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;

          // Si está reproduciendo, reiniciar contadores de error
          if (_isPlaying) {
            _retryCount = 0;
            _consecutiveErrors = 0;
            if (!_errorController.isClosed) {
              _errorController.add('');
            }
            _startHealthCheck();
            _startConnectivityCheck();
          } else {
            // Si se detuvo inesperadamente, intentar reconectar
            if (wasPlaying && !_userStoppedManually && !_isRestarting) {
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
        },
        onError: (error) {
          _consecutiveErrors++;
          _handlePlayerError(error);
        },
      );

      // Escuchar eventos de playback
      _audioPlayer!.playbackEventStream.listen(
        (event) {},
        onError: (error) {
          _handlePlayerError(error);
        },
      );

      // Aplicar volumen inicial
      _audioPlayer!.setVolume(_volume);
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al inicializar player: $e');
      }
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
    if (_isRestarting) return;

    try {
      _userStoppedManually = false;
      _isLoading = true;
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
      }

      // Verificar conectividad antes de intentar reproducir
      final hasConnection = await _checkRealConnectivity();

      if (!hasConnection) {
        _isLoading = false;
        _isPlaying = false;
        if (!_loadingController.isClosed) {
          _loadingController.add(_isLoading);
        }
        if (!_playingController.isClosed) {
          _playingController.add(_isPlaying);
        }
        if (!_errorController.isClosed) {
          _errorController.add('Sin conexión. Reintentando...');
        }
        _scheduleReconnect();
        return;
      }

      // Si hay muchos errores consecutivos, forzar reinicio
      if (_consecutiveErrors > 3) {
        await _forceRestart();
        return;
      }

      // Configurar URL y reproducir
      await _audioPlayer?.setUrl(streamUrl);
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
        _errorController.add('Error al conectar. Reintentando...');
      }
      _scheduleReconnect();
    }
  }

  /// Detiene la reproducción
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
      if (!_playingController.isClosed) {
        _playingController.add(_isPlaying);
      }
      if (!_loadingController.isClosed) {
        _loadingController.add(_isLoading);
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
  /// Se usa cuando hay múltiples errores consecutivos
  Future<void> _forceRestart() async {
    if (_isRestarting) return;

    _isRestarting = true;

    try {
      _cancelReconnect();
      _stopHealthCheck();
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
      await Future.delayed(const Duration(milliseconds: 500));

      _consecutiveErrors = 0;

      // Si el usuario detuvo manualmente, no continuar
      if (_userStoppedManually) {
        _isRestarting = false;
        _isLoading = false;
        if (!_loadingController.isClosed) {
          _loadingController.add(_isLoading);
        }
        return;
      }

      // Verificar conectividad
      final hasConnection = await _checkRealConnectivity();

      if (!hasConnection) {
        _isRestarting = false;
        _isLoading = false;
        if (!_loadingController.isClosed) {
          _loadingController.add(_isLoading);
        }
        if (!_errorController.isClosed) {
          _errorController.add('Sin conexión. Reintentando...');
        }
        _scheduleReconnect();
        return;
      }

      // Reiniciar reproducción
      await _audioPlayer?.setUrl(streamUrl);
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
        _errorController.add('Error. Reintentando...');
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

  /// Verifica la conectividad real haciendo una petición HTTP al stream
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

  /// Inicia un timer para verificar la conectividad periódicamente
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
          _isPlaying = false;
          if (!_playingController.isClosed) {
            _playingController.add(_isPlaying);
          }
          if (!_errorController.isClosed) {
            _errorController.add('Sin conexión');
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
    if (_isRestarting) return;

    _isLoading = false;
    _isPlaying = false;
    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }
    if (!_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }

    if (!_userStoppedManually) {
      if (_consecutiveErrors > 5) {
        if (!_errorController.isClosed) {
          _errorController.add('Reiniciando...');
        }
        _forceRestart();
      } else {
        if (!_errorController.isClosed) {
          _errorController.add('Reintentando...');
        }
        _scheduleReconnect();
      }
    }
  }

  /// Programa un intento de reconexión con retroceso exponencial
  void _scheduleReconnect() {
    if (_isRestarting) return;

    _cancelReconnect();

    // Si se alcanzó el máximo de intentos, usar el delay máximo
    if (_retryCount >= _maxRetries) {
      if (!_errorController.isClosed) {
        _errorController.add('Reintentando en ${_maxRetryDelay.inSeconds}s...');
      }
      _retryTimer = Timer(_maxRetryDelay, () {
        _retryCount = 0;
        _attemptReconnect();
      });
      return;
    }

    // Calcular delay con retroceso exponencial
    final delay = Duration(
      seconds: (_initialRetryDelay.inSeconds * (1 << _retryCount)).clamp(
        2,
        _maxRetryDelay.inSeconds,
      ),
    );

    _retryTimer = Timer(delay, _attemptReconnect);
  }

  /// Intenta reconectar al stream
  Future<void> _attemptReconnect() async {
    if (_userStoppedManually || _isRestarting) return;

    _retryCount++;

    final hasConnection = await _checkRealConnectivity();

    if (!hasConnection) {
      if (!_errorController.isClosed) {
        _errorController.add('Sin conexión. Reintentando...');
      }
      _scheduleReconnect();
      return;
    }

    // Si hay muchos errores, forzar reinicio completo
    if (_consecutiveErrors > 5) {
      await _forceRestart();
      return;
    }

    _isLoading = true;
    if (!_loadingController.isClosed) {
      _loadingController.add(_isLoading);
    }

    try {
      await _audioPlayer?.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      await _audioPlayer?.setUrl(streamUrl);
      await _audioPlayer?.play();

      if (!_errorController.isClosed) {
        _errorController.add('Reconectado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error reconexión: $e');
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
      _scheduleReconnect();
    }
  }

  /// Cancela el timer de reconexión
  void _cancelReconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Inicia un timer de verificación de salud del reproductor
  void _startHealthCheck() {
    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isPlaying && !_userStoppedManually && !_isRestarting) {
        // Timer de verificación periódica
      }
    });
  }

  /// Detiene el timer de verificación de salud
  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Establece el volumen tanto en el reproductor como en el sistema
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);

      // Aplicar al reproductor de audio
      await _audioPlayer?.setVolume(_volume);

      // Sincronizar con el volumen del sistema
      VolumeController.instance.setVolume(_volume);

      // Emitir cambio al stream
      if (!_volumeStreamController.isClosed) {
        _volumeStreamController.add(_volume);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AudioPlayerManager] Error al establecer volumen: $e');
      }
    }
  }

  /// Libera todos los recursos utilizados
  void dispose() {
    _isRestarting = false;
    _cancelReconnect();
    _stopHealthCheck();
    _stopConnectivityCheck();

    _playerStateSubscription?.cancel();

    _playingController.close();
    _loadingController.close();
    _volumeStreamController.close();
    _errorController.close();

    _audioPlayer?.dispose();

    // Remover listener del volumen
    VolumeController.instance.removeListener();
  }
}
