import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_session/audio_session.dart';

/// Gestor centralizado del reproductor de audio
/// Implementa el patrón Singleton para mantener una única instancia
/// Maneja el streaming de radio, control de volumen y estado de reproducción
class AudioPlayerManager {
  // ========== SINGLETON PATTERN ==========
  static AudioPlayerManager? _instance;

  /// Factory constructor que retorna siempre la misma instancia
  factory AudioPlayerManager() {
    _instance ??= AudioPlayerManager._internal();
    return _instance!;
  }

  /// Constructor privado para el singleton
  AudioPlayerManager._internal() {
    _log('[AudioPlayerManager] Creando instancia singleton');
    _initAsync();
  }

  // ========== CONSTANTES ==========
  /// URL del stream de radio
  static const String _streamUrl = 'https://radio06.cehis.net:9036/stream';

  /// Intervalo de reconexión en caso de fallo
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Número máximo de intentos de reconexión
  static const int _maxReconnectAttempts = 5;

  /// Configuración de auto-inicio
  static const bool _autoPlay = true;

  // ========== WAKE LOCK ==========
  static const _wakeLockChannel = MethodChannel(
    'com.miltonbass.ambeinte_stereo_884/wakelock',
  );

  // ========== PLAYER Y ESTADO ==========
  /// Reproductor de audio principal
  AudioPlayer? _player;

  /// Indica si el gestor está inicializado
  bool _isInitialized = false;

  /// Bandera para evitar múltiples inicializaciones simultáneas
  bool _isInitializing = false;

  // ========== STREAMS DE ESTADO ==========
  final BehaviorSubject<bool> _playingController = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<bool> _loadingController = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<String> _errorController =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<double> _volumeController =
      BehaviorSubject<double>.seeded(1.0);

  // ========== CONTROL DE RECONEXIÓN ==========
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  // ========== GETTERS PÚBLICOS ==========
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  bool get isPlaying => _playingController.value;
  bool get isLoading => _loadingController.value;
  double get volume => _volumeController.value;

  // ========== INICIALIZACIÓN ==========
  Future<void> _initAsync() async {
    if (_isInitialized || _isInitializing) {
      _log(
        '[AudioPlayerManager] Ya está inicializado o inicializando, ignorando',
      );
      return;
    }

    _isInitializing = true;
    _log('[AudioPlayerManager] Iniciando inicialización asíncrona...');

    try {
      // Limpiar player anterior si existe
      if (_player != null) {
        _log('[AudioPlayerManager] Limpiando player anterior...');
        await _player!.dispose();
        _player = null;
      }

      // Crear el reproductor
      _player = AudioPlayer();
      _log('[AudioPlayerManager] 🎵 AudioPlayer creado');

      // Configurar la sesión de audio para reproducción en segundo plano
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _log(
        '[AudioPlayerManager] ✅ AudioSession configurado para segundo plano',
      );

      // Activar WakeLock mediante MainActivity
      try {
        await _wakeLockChannel.invokeMethod('acquireWakeLock');
        _log('[AudioPlayerManager] ✅ WakeLock activado');
      } catch (e) {
        _log('[AudioPlayerManager] ⚠️ Error activando WakeLock: $e');
        // Continuar sin WakeLock
      }

      // Configurar el audio source
      await _player!.setAudioSource(AudioSource.uri(Uri.parse(_streamUrl)));
      _log('[AudioPlayerManager] ✅ Player configurado con URL: $_streamUrl');

      // Configurar listeners de estado
      _setupPlayerListeners();

      // Marcar como inicializado
      _isInitialized = true;
      _isInitializing = false;

      // Emitir estado inicial
      _playingController.add(false);
      _loadingController.add(false);

      _log('[AudioPlayerManager] ✅ Inicialización completa');

      // Auto-iniciar reproducción si está habilitado
      if (_autoPlay) {
        _log('[AudioPlayerManager] 🎵 Auto-iniciando reproducción...');
        Future.delayed(const Duration(milliseconds: 500), () {
          play();
        });
      }
    } catch (e) {
      _isInitializing = false;
      _isInitialized = false;

      _log('[AudioPlayerManager] ❌ Error en inicialización: $e');

      String errorMessage = 'Error al inicializar';
      if (e.toString().contains('404')) {
        errorMessage = 'Stream no disponible (404). Verifica la URL.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Timeout al conectar. Verifica tu conexión.';
      } else if (e.toString().contains('Source error')) {
        errorMessage = 'Error en el stream. Verifica la URL.';
      }

      _errorController.add(errorMessage);
      _loadingController.add(false);

      if (_player != null) {
        try {
          await _player!.dispose();
        } catch (_) {}
        _player = null;
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    int waitCount = 0;
    while (_isInitializing && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (!_isInitialized && !_isInitializing) {
      _log('[AudioPlayerManager] ⚠️ No inicializado, reintentando...');
      await _initAsync();
    }
  }

  void _setupPlayerListeners() {
    if (_player == null) return;

    // Listener del estado de reproducción
    _player!.playingStream.listen((playing) {
      _log(
        '[AudioPlayerManager] 📊 Estado: playing=$playing, ${_player!.processingState}',
      );
      _playingController.add(playing);
      _loadingController.add(false);
    });

    // Listener del estado de procesamiento
    _player!.processingStateStream.listen((state) {
      _log('[AudioPlayerManager] 🔄 ProcessingState: $state');

      if (state == ProcessingState.idle && _player!.playing) {
        _log('[AudioPlayerManager] 🔄 Stream desconectado, reconectando...');
        _handleReconnection();
      }
    });

    // Listener de errores
    _player!.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        _log('[AudioPlayerManager] ❌ Error en playback: $e');
        if (_player != null && _player!.playing) {
          _handleReconnection();
        }
      },
    );
  }

  // ========== TOGGLE PLAYBACK ==========
  Future<void> togglePlayback() async {
    try {
      await _ensureInitialized();

      if (!_isInitialized) {
        _errorController.add('No se pudo inicializar el reproductor');
        return;
      }

      if (isPlaying) {
        await pause();
      } else {
        await play();
      }
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error en togglePlayback: $e');
      _errorController.add('Error al cambiar reproducción');
      rethrow;
    }
  }

  // ========== CONTROL DE REPRODUCCIÓN ==========
  Future<void> play() async {
    try {
      await _ensureInitialized();

      if (!_isInitialized || _player == null) {
        _errorController.add('Reproductor no disponible');
        _loadingController.add(false);
        return;
      }

      _loadingController.add(true);
      _errorController.add('');

      _log('[AudioPlayerManager] ▶️ Iniciando reproducción...');
      await _player!.play();

      _reconnectAttempts = 0;
      _isReconnecting = false;
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al reproducir: $e');
      _loadingController.add(false);

      String errorMessage = 'Error al conectar';
      if (e.toString().contains('404')) {
        errorMessage = 'Stream no disponible. Verifica la URL.';
      }
      _errorController.add(errorMessage);
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _ensureInitialized();

      if (_player == null) return;

      _log('[AudioPlayerManager] ⏸️ Pausando reproducción...');
      await _player!.pause();
      _loadingController.add(false);

      _reconnectTimer?.cancel();
      _isReconnecting = false;
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al pausar: $e');
      _errorController.add('Error al pausar');
    }
  }

  // ========== CONTROL DE VOLUMEN ==========
  Future<void> setVolume(double volume) async {
    try {
      await _ensureInitialized();

      if (_player == null) return;

      final clampedVolume = volume.clamp(0.0, 1.0);
      await _player!.setVolume(clampedVolume);
      _volumeController.add(clampedVolume);
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al cambiar volumen: $e');
    }
  }

  // ========== RECONEXIÓN AUTOMÁTICA ==========
  void _handleReconnection() {
    if (_isReconnecting) {
      _log('[AudioPlayerManager] ⚠️ Reconexión en progreso...');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('[AudioPlayerManager] ❌ Máximo de reconexiones alcanzado');
      _errorController.add('No se pudo reconectar. Intenta nuevamente.');
      _loadingController.add(false);
      return;
    }

    if (_player == null) {
      _log('[AudioPlayerManager] ❌ Player no disponible para reconexión');
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    _loadingController.add(true);
    _errorController.add('Reconectando... (intento $_reconnectAttempts)');

    _log(
      '[AudioPlayerManager] 🔄 Intento de reconexión $_reconnectAttempts/$_maxReconnectAttempts',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      try {
        if (_player != null) {
          await _player!.stop();
          await _player!.play();
          _isReconnecting = false;
          _errorController.add('Reconectado exitosamente');
          _log('[AudioPlayerManager] ✅ Reconexión exitosa');
        }
      } catch (e) {
        _log('[AudioPlayerManager] ❌ Error en reconexión: $e');
        _isReconnecting = false;
        _handleReconnection();
      }
    });
  }

  // ========== CLEANUP ==========
  Future<void> dispose() async {
    _log('[AudioPlayerManager] 🧹 Liberando recursos...');

    _reconnectTimer?.cancel();

    await _playingController.close();
    await _loadingController.close();
    await _errorController.close();
    await _volumeController.close();

    // ✅ Liberar WakeLock
    try {
      await _wakeLockChannel.invokeMethod('releaseWakeLock');
      _log('[AudioPlayerManager] ✅ WakeLock liberado');
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error liberando WakeLock: $e');
    }

    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }

    _log('[AudioPlayerManager] ✅ Recursos liberados');
  }

  // ========== LOGGING ==========
  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }
}
