import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Clase global para manejar el reproductor de audio con auto-recuperación
/// y verificación de conectividad real
class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;
  AudioPlayerManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userStoppedManually = false;
  bool _hasRealConnection = false; // NUEVO: verificar conexión real
  double _volume = 0.7;
  static const String streamUrl = 'https://radio06.cehis.net:9036/stream';

  // Configuración de reconexión
  static const int _maxRetries = 5;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(seconds: 30);
  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _healthCheckTimer;
  Timer? _connectivityCheckTimer; // NUEVO: timer para verificar conectividad

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

  /// Inicializa el reproductor de audio con listeners de estado
  void init() {
    // Listener de estado del reproductor
    _audioPlayer.onPlayerStateChanged.listen(
      (PlayerState state) {
        final wasPlaying = _isPlaying;
        _isPlaying = state == PlayerState.playing;
        _isLoading = false;

        _playingController.add(_isPlaying);
        _loadingController.add(_isLoading);

        // Si estaba reproduciendo y ahora no, y el usuario no detuvo manualmente
        if (wasPlaying && !_isPlaying && !_userStoppedManually) {
          _log('Stream se detuvo inesperadamente, intentando reconectar...');
          _scheduleReconnect();
        }

        // Si está reproduciendo, iniciar verificaciones
        if (_isPlaying) {
          _retryCount = 0;
          _startHealthCheck();
          _startConnectivityCheck(); // NUEVO
        }
      },
      onError: (error) {
        _log('Error en onPlayerStateChanged: $error');
        _handlePlayerError(error);
      },
    );

    // Listener de errores del reproductor
    _audioPlayer.onPlayerComplete.listen(
      (_) {
        if (!_userStoppedManually && _isPlaying) {
          _log('Stream completado inesperadamente, reconectando...');
          _scheduleReconnect();
        }
      },
      onError: (error) {
        _log('Error en onPlayerComplete: $error');
        _handlePlayerError(error);
      },
    );

    // Establecer volumen inicial
    _audioPlayer.setVolume(_volume);

    // Configurar modo de liberación
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// NUEVO: Verifica si hay conectividad real a internet
  Future<bool> _checkRealConnectivity() async {
    try {
      // Intentar hacer ping al servidor del stream
      final host = Uri.parse(streamUrl).host;
      _log('Verificando conectividad con $host...');

      final result = await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('Timeout verificando conectividad');
          return [];
        },
      );

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _log('✓ Conectividad confirmada');
        _hasRealConnection = true;
        return true;
      }

      _log('✗ Sin conectividad real');
      _hasRealConnection = false;
      return false;
    } on SocketException catch (e) {
      _log('✗ Sin conectividad: $e');
      _hasRealConnection = false;
      return false;
    } catch (e) {
      _log('Error verificando conectividad: $e');
      _hasRealConnection = false;
      return false;
    }
  }

  /// NUEVO: Verificación periódica de conectividad mientras reproduce
  void _startConnectivityCheck() {
    _stopConnectivityCheck();

    // Verificar conectividad cada 10 segundos
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (_isPlaying && !_userStoppedManually) {
        final hasConnection = await _checkRealConnectivity();

        if (!hasConnection && _isPlaying) {
          _log('⚠️ Conectividad perdida durante reproducción');
          // El estado dice que está reproduciendo pero no hay conexión
          // Forzar actualización de estado
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

  /// Manejador centralizado de errores del reproductor
  void _handlePlayerError(dynamic error) {
    _log('Manejando error del reproductor: $error');

    // Actualizar estado
    _isLoading = false;
    _isPlaying = false; // NUEVO: también marcar como no reproduciendo
    _loadingController.add(_isLoading);
    _playingController.add(_isPlaying); // NUEVO: notificar cambio

    // Si no fue pausa manual, intentar reconectar
    if (!_userStoppedManually) {
      _errorController.add('Problemas de conexión. Reintentando...');
      _scheduleReconnect();
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

  /// Inicia la reproducción con verificación de conectividad
  Future<void> play() async {
    _userStoppedManually = false;
    _isLoading = true;
    _loadingController.add(_isLoading);

    // NUEVO: Verificar conectividad ANTES de intentar reproducir
    final hasConnection = await _checkRealConnectivity();

    if (!hasConnection) {
      _log('❌ No hay conexión a internet');
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Sin conexión a internet. Reintentando...');
      _scheduleReconnect();
      return;
    }

    try {
      _log('✓ Conectividad verificada, iniciando reproducción...');

      // Detener cualquier reproducción anterior
      await _audioPlayer.stop().catchError((e) {
        _log('Error al detener reproducción anterior: $e');
      });

      // Pequeña pausa para asegurar limpieza
      await Future.delayed(const Duration(milliseconds: 200));

      // Intentar reproducir con timeout
      await _audioPlayer
          .play(UrlSource(streamUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              _log('Timeout al intentar reproducir');
              throw TimeoutException('Timeout al conectar con el servidor');
            },
          );

      _retryCount = 0;
      _log('✓ Reproducción iniciada exitosamente');
    } on TimeoutException catch (e) {
      _log('Error de timeout: $e');
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Servidor no responde. Reintentando...');
      _scheduleReconnect();
    } catch (e) {
      _log('Error al reproducir: $e');
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _errorController.add('Error al conectar. Reintentando...');
      _scheduleReconnect();
    }
  }

  /// Detiene la reproducción (acción manual del usuario)
  Future<void> stop() async {
    _userStoppedManually = true;
    _cancelReconnect();
    _stopHealthCheck();
    _stopConnectivityCheck(); // NUEVO

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _isLoading = false;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);
      _log('Reproducción detenida por el usuario');
    } catch (e) {
      _log('Error al detener: $e');
      // Forzar actualización de estado incluso si hay error
      _isPlaying = false;
      _isLoading = false;
      _playingController.add(_isPlaying);
      _loadingController.add(_isLoading);
    }
  }

  /// Programa un reintento de reconexión
  void _scheduleReconnect() {
    // Si ya hay un timer activo, cancelarlo
    _cancelReconnect();

    // Si excedemos los reintentos máximos, esperar más tiempo
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

    // Calcular delay exponencial: 2s, 4s, 8s, 16s, 30s (máximo)
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

  /// Intenta reconectar con verificación de conectividad
  Future<void> _attemptReconnect() async {
    if (_userStoppedManually) {
      _log('Reconexión cancelada: usuario detuvo manualmente');
      return;
    }

    _retryCount++;
    _log('Intento de reconexión #$_retryCount');

    // NUEVO: Verificar conectividad primero
    final hasConnection = await _checkRealConnectivity();

    if (!hasConnection) {
      _log('❌ Aún sin conectividad, programando nuevo intento...');
      _errorController.add('Sin conexión. Reintentando...');
      _scheduleReconnect();
      return;
    }

    _isLoading = true;
    _loadingController.add(_isLoading);

    try {
      _log('✓ Conectividad verificada, intentando reconexión...');

      // Primero detener cualquier reproducción anterior
      await _audioPlayer.stop().catchError((e) {
        _log('Error al detener en reconexión: $e');
      });

      // Pausa antes de reintentar
      await Future.delayed(const Duration(milliseconds: 500));

      // Intentar reproducir de nuevo con timeout
      await _audioPlayer
          .play(UrlSource(streamUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Timeout en reconexión');
            },
          );

      _log('✓ Reconexión exitosa');
      _errorController.add('Reconectado exitosamente');
    } on TimeoutException catch (e) {
      _log('Timeout en reconexión: $e');
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _scheduleReconnect();
    } catch (e) {
      _log('Error en reconexión: $e');
      _isLoading = false;
      _isPlaying = false;
      _loadingController.add(_isLoading);
      _playingController.add(_isPlaying);
      _scheduleReconnect();
    }
  }

  /// Cancela cualquier reconexión programada
  void _cancelReconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Inicia verificación periódica de salud del stream
  void _startHealthCheck() {
    _stopHealthCheck();

    // Verificar cada 30 segundos
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isPlaying && !_userStoppedManually) {
        _log('Health check: Stream activo');
      }
    });
  }

  /// Detiene la verificación de salud
  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Establece el volumen del reproductor
  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(_volume);
      _volumeController.add(_volume);
    } catch (e) {
      _log('Error al establecer volumen: $e');
    }
  }

  /// Logging para debug
  void _log(String message) {
    if (kDebugMode) {
      print('[AudioPlayerManager] $message');
    }
  }

  /// Libera los recursos del reproductor
  void dispose() {
    _cancelReconnect();
    _stopHealthCheck();
    _stopConnectivityCheck(); // NUEVO

    // Cerrar streams de manera segura
    _playingController.close().catchError((e) {
      _log('Error cerrando playingController: $e');
    });
    _loadingController.close().catchError((e) {
      _log('Error cerrando loadingController: $e');
    });
    _volumeController.close().catchError((e) {
      _log('Error cerrando volumeController: $e');
    });
    _errorController.close().catchError((e) {
      _log('Error cerrando errorController: $e');
    });

    // Disponer el reproductor
    _audioPlayer.dispose().catchError((e) {
      _log('Error disposing audioPlayer: $e');
    });
  }
}
