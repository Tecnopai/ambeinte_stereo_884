import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Clase global para manejar el reproductor de audio con auto-recuperación
/// y verificación REAL de conectividad con descarga de datos
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userStoppedManually = false;
  double _volume = 0.7;
  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';

  // Configuración de reconexión
  static const int _maxRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(seconds: 30);
  int _retryCount = 0;
  int _consecutiveErrors = 0;
  Timer? _retryTimer;
  Timer? _healthCheckTimer;
  Timer? _connectivityCheckTimer;
  Timer? _audioCheckTimer;

  // Para detectar stream congelado y controlar reinicio
  bool _isRestarting = false;
  DateTime? _lastPositionUpdate; // NUEVO: Solo verificar después de reconexión

  // Subscripciones para poder cancelarlas
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;
  StreamSubscription?
  _positionSubscription; // CAMBIO: position en lugar de duration

  // Stream controllers para notificar cambios
  final _playingController = StreamController<bool>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Getters para los streams
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters para el estado actual
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get volume => _volume;

  /// Inicializa o reinicia el reproductor de audio
  void _initializePlayer() {
    // Cancelar subscripciones anteriores
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _positionSubscription?.cancel();

    // Disponer player anterior si existe
    _audioPlayer?.dispose();

    // Crear nuevo player
    _audioPlayer = AudioPlayer();

    // MEJORADO: Escuchar cambios de posición para detectar streams activos
    _positionSubscription = _audioPlayer!.onPositionChanged.listen(
      (Duration position) {
        // Se dispara cada ~200ms cuando el stream está activo
        _lastPositionUpdate = DateTime.now();
      },
      onError: (error) {
        if (_isRestarting) return;
        _log('❌ Error en onPositionChanged: $error');
      },
      cancelOnError: false,
    );

    // Configurar listeners con subscripciones que podemos cancelar
    _stateSubscription = _audioPlayer!.onPlayerStateChanged.listen(
      (PlayerState state) {
        // Ignorar eventos durante reinicio excepto playing
        if (_isRestarting && state != PlayerState.playing) {
          _log('Estado durante reinicio ignorado: $state');
          return;
        }

        _log('Estado del reproductor: $state');

        final wasPlaying = _isPlaying;
        _isPlaying = state == PlayerState.playing;
        _isLoading = false;

        _playingController.add(_isPlaying);
        _loadingController.add(_isLoading);

        // Solo reconectar si NO estamos en proceso de reinicio
        if (wasPlaying &&
            !_isPlaying &&
            !_userStoppedManually &&
            !_isRestarting) {
          _log('Stream se detuvo inesperadamente, intentando reconectar...');
          _consecutiveErrors++;
          _scheduleReconnect();
        }

        if (_isPlaying) {
          _retryCount = 0;
          _consecutiveErrors = 0;
          _startHealthCheck();
          _startConnectivityCheck();
          _startAudioCheck();
        }
      },
      onError: (error) {
        if (_isRestarting) return;
        _log('❌ Error en onPlayerStateChanged: $error');
        _consecutiveErrors++;
        _handlePlayerError(error);
      },
      cancelOnError: false,
    );

    _completeSubscription = _audioPlayer!.onPlayerComplete.listen(
      (_) {
        if (_isRestarting) return;
        if (!_userStoppedManually && _isPlaying) {
          _log('Stream completado inesperadamente, reconectando...');
          _consecutiveErrors++;
          _scheduleReconnect();
        }
      },
      onError: (error) {
        if (_isRestarting) return;
        _log('❌ Error en onPlayerComplete: $error');
        _consecutiveErrors++;
        _handlePlayerError(error);
      },
      cancelOnError: false,
    );

    _audioPlayer!.setVolume(_volume);
    _audioPlayer!.setReleaseMode(ReleaseMode.loop);
  }

  /// Inicializa el sistema
  void init() {
    _initializePlayer();
  }

  /// SIMPLIFICADO: Solo verifica stream congelado, no audio fantasma
  void _startAudioCheck() {
    _stopAudioCheck();

    _audioCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isPlaying &&
          !_userStoppedManually &&
          !_isLoading &&
          !_isRestarting) {
        // Solo verificar si hay position updates cuando esperamos que los haya
        if (_lastPositionUpdate != null) {
          final timeSinceLastUpdate = DateTime.now().difference(
            _lastPositionUpdate!,
          );

          // Si llevamos más de 15 segundos sin updates de posición
          if (timeSinceLastUpdate.inSeconds > 10) {
            _log(
              '⚠️ Stream sin actividad por ${timeSinceLastUpdate.inSeconds}s',
            );

            // Solo reiniciar si también hay errores consecutivos
            if (_consecutiveErrors >= 3) {
              _log('🔄 Forzando reinicio por stream inactivo con errores...');
              timer.cancel();
              _forceRestart();
              return;
            }
          }
        }

        // Verificar errores consecutivos solamente
        if (_consecutiveErrors > 3) {
          _log('⚠️ Demasiados errores consecutivos, reiniciando player...');
          timer.cancel();
          _forceRestart();
          return;
        }
      }
    });
  }

  void _stopAudioCheck() {
    _audioCheckTimer?.cancel();
    _audioCheckTimer = null;
  }

  /// MEJORADO: Reinicio con subscripciones canceladas
  Future<void> _forceRestart() async {
    if (_isRestarting) {
      _log('⚠️ Ya hay un reinicio en curso, ignorando...');
      return;
    }

    _log('🔄 Forzando reinicio completo del reproductor...');
    _isRestarting = true;

    try {
      // 1. Cancelar TODOS los timers y reconexiones
      _cancelReconnect();
      _stopAudioCheck();
      _stopHealthCheck();
      _stopConnectivityCheck();

      // 2. Cancelar subscripciones a eventos
      _log('Cancelando subscripciones...');
      await _stateSubscription?.cancel();
      await _completeSubscription?.cancel();
      await _positionSubscription?.cancel();
      _stateSubscription = null;
      _completeSubscription = null;
      _positionSubscription = null;

      // 3. Actualizar estado UI
      _isLoading = true;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Reiniciando reproductor...');

      // 4. Detener player sin esperar eventos
      _log('Deteniendo player...');
      try {
        await _audioPlayer?.stop();
      } catch (e) {
        _log('Error al detener (ignorado): $e');
      }

      // 5. Dispose del player
      _log('Disposing player...');
      try {
        await _audioPlayer?.dispose();
      } catch (e) {
        _log('Error al dispose (ignorado): $e');
      }
      _audioPlayer = null;

      // 6. Esperar para limpiar completamente
      await Future.delayed(const Duration(milliseconds: 300));

      // 7. Reinicializar completamente (esto crea nuevas subscripciones)
      _log('Reinicializando player...');
      _consecutiveErrors = 0;
      _lastPositionUpdate = null;
      _initializePlayer();

      // 8. Esperar antes de reproducir
      await Future.delayed(const Duration(milliseconds: 200));

      // 9. Verificar si debemos reproducir
      if (_userStoppedManually) {
        _log('Usuario detuvo manualmente, no reproducir');
        _isRestarting = false;
        _isLoading = false;
        _loadingController.add(_isLoading);
        return;
      }

      // 10. Verificar conectividad
      _log('Verificando conectividad...');
      final hasConnection = await _checkRealConnectivity();

      if (!hasConnection) {
        _log('❌ Sin conexión después del reinicio');
        _isRestarting = false;
        _isLoading = false;
        _loadingController.add(_isLoading);
        _errorController.add('Sin conexión. Reintentando...');
        _scheduleReconnect();
        return;
      }

      // 11. Reproducir
      _log('♻️ Reproduciendo después del reinicio...');
      try {
        await _audioPlayer
            ?.play(UrlSource(streamUrl))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Timeout en reinicio');
              },
            );

        _lastPositionUpdate = DateTime.now();
        _log('✅ Reinicio completado exitosamente');
        _errorController.add('');
      } catch (e) {
        _log('❌ Error al reproducir después de reinicio: $e');
        rethrow;
      }
    } catch (e) {
      _log('❌ Error en reinicio forzado: $e');
      _isLoading = false;
      _loadingController.add(_isLoading);
      _errorController.add('Error al reiniciar. Reintentando...');
      _scheduleReconnect();
    } finally {
      _isRestarting = false;
      _isLoading = false;
      _loadingController.add(_isLoading);
    }
  }

  /// Verifica conectividad REAL
  Future<bool> _checkRealConnectivity() async {
    try {
      final response = await http
          .head(Uri.parse(streamUrl))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Timeout');
            },
          );

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 301 ||
          response.statusCode == 403 ||
          response.statusCode == 400) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// SIMPLIFICADO: Verificación periódica sin audio fantasma
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

        if (!hasConnection && _isPlaying) {
          _log('⚠️ Conectividad perdida durante reproducción');
          _isPlaying = false;
          _playingController.add(_isPlaying);
          _errorController.add('Sin conexión a internet');
          _scheduleReconnect();
        }
      }
    });
  }

  void _stopConnectivityCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = null;
  }

  /// Manejador de errores
  void _handlePlayerError(dynamic error) {
    if (_isRestarting) {
      _log('⚠️ Error durante reinicio (ignorado): $error');
      return;
    }

    _log('⚠️ Manejando error del reproductor: $error');

    _isLoading = false;
    _isPlaying = false;
    _loadingController.add(_isLoading);
    _playingController.add(_isPlaying);

    if (!_userStoppedManually) {
      if (_consecutiveErrors > 5) {
        _errorController.add('Reiniciando reproductor...');
        _forceRestart();
      } else {
        _errorController.add('Problemas de conexión. Reintentando...');
        _scheduleReconnect();
      }
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
      _log('⚠️ Reinicio en curso, esperando...');
      return;
    }

    try {
      _userStoppedManually = false;
      _isLoading = true;
      _loadingController.add(_isLoading);
      _lastPositionUpdate = DateTime.now();

      final hasConnection = await _checkRealConnectivity();

      if (!hasConnection) {
        _log('❌ Sin conexión REAL a internet');
        _isLoading = false;
        _isPlaying = false;
        _loadingController.add(_isLoading);
        _playingController.add(_isPlaying);
        _errorController.add('Sin conexión a internet. Reintentando...');
        _scheduleReconnect();
        return;
      }

      _log('✅ Conectividad verificada, iniciando reproducción...');

      if (_consecutiveErrors > 3) {
        _log('Reiniciando player por errores consecutivos...');
        await _forceRestart();
        return;
      }

      await _audioPlayer?.stop().catchError((e) {
        _log('Error al detener reproducción anterior (ignorado): $e');
        return null;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      await _audioPlayer
          ?.play(UrlSource(streamUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              _log('Timeout al intentar reproducir');
              throw TimeoutException('Timeout al conectar con el servidor');
            },
          );

      _retryCount = 0;
      _lastPositionUpdate = DateTime.now();
      _log('✅ Reproducción iniciada exitosamente');
    } on TimeoutException catch (e) {
      _log('❌ Error de timeout: $e');
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Servidor no responde. Reintentando...');
      _scheduleReconnect();
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
      _stopAudioCheck();

      await _audioPlayer?.stop().catchError((e) {
        _log('Error al detener (ignorado): $e');
        return null;
      });

      _isPlaying = false;
      _isLoading = false;
      _lastPositionUpdate = null;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);
      _log('Reproducción detenida por el usuario');
    } catch (e) {
      _log('❌ Error en stop: $e');
      _isPlaying = false;
      _isLoading = false;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);
    }
  }

  /// Programa reconexión
  void _scheduleReconnect() {
    if (_isRestarting) {
      _log('⚠️ Reinicio en curso, no programar reconexión');
      return;
    }

    _cancelReconnect();

    if (_retryCount >= _maxRetries) {
      _log(
        'Máximo de reintentos alcanzado, esperando $_maxRetryDelay antes de reintentar...',
      );
      _errorController.add(
        'Sin conexión. Reintentando en ${_maxRetryDelay.inSeconds}s...',
      );

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

    _log(
      'Reconectando en ${delay.inSeconds} segundos (intento ${_retryCount + 1}/$_maxRetries)...',
    );

    _retryTimer = Timer(delay, _attemptReconnect);
  }

  /// Intenta reconectar
  Future<void> _attemptReconnect() async {
    if (_userStoppedManually || _isRestarting) {
      _log('Reconexión cancelada');
      return;
    }

    _retryCount++;
    _log('Intento de reconexión #$_retryCount');

    final hasConnection = await _checkRealConnectivity();

    if (!hasConnection) {
      _log('❌ Aún sin conectividad REAL, programando nuevo intento...');
      _errorController.add('Sin conexión. Reintentando...');
      _scheduleReconnect();
      return;
    }

    if (_consecutiveErrors > 5) {
      _log('Demasiados errores, haciendo reinicio completo...');
      await _forceRestart();
      return;
    }

    _isLoading = true;
    _loadingController.add(_isLoading);

    try {
      _log('✅ Conectividad verificada, intentando reconexión...');
      await _audioPlayer?.stop().catchError((e) {
        _log('Error al detener en reconexión (ignorado): $e');
        return null;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      await _audioPlayer
          ?.play(UrlSource(streamUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Timeout en reconexión');
            },
          );

      _lastPositionUpdate = DateTime.now();
      _log('✅ Reconexión exitosa');
      _errorController.add('Reconectado exitosamente');
    } on TimeoutException catch (e) {
      _log('❌ Timeout en reconexión: $e');
      _consecutiveErrors++;
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _scheduleReconnect();
    } catch (e) {
      _log('❌ Error en reconexión: $e');
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
        _log('Health check: Stream activo');
      }
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer?.setVolume(_volume);
      _volumeController.add(_volume);
    } catch (e) {
      _log('Error al establecer volumen: $e');
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
    _stopAudioCheck();

    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _positionSubscription?.cancel();

    _playingController.close().catchError(
      (e) => _log('Error cerrando playingController: $e'),
    );
    _loadingController.close().catchError(
      (e) => _log('Error cerrando loadingController: $e'),
    );
    _volumeController.close().catchError(
      (e) => _log('Error cerrando volumeController: $e'),
    );
    _errorController.close().catchError(
      (e) => _log('Error cerrando errorController: $e'),
    );

    _audioPlayer?.dispose().catchError(
      (e) => _log('Error disposing audioPlayer: $e'),
    );
  }
}
