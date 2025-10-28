import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:radio_player/radio_player.dart';
import 'package:rxdart/rxdart.dart';

/// Gestor centralizado del reproductor de audio usando radio_player
/// Implementa el patrón Singleton para mantener una única instancia
/// Maneja el streaming de radio, control de volumen y estado de reproducción
/// ✅ Incluye notificaciones automáticas (sin configuración adicional)
class AudioPlayerManager {
  // ========== SINGLETON PATTERN ==========
  static AudioPlayerManager? _instance;

  factory AudioPlayerManager() {
    _instance ??= AudioPlayerManager._internal();
    return _instance!;
  }

  AudioPlayerManager._internal() {
    _log('[AudioPlayerManager] Creando instancia singleton');
    _initAsync();
  }

  // ========== CONSTANTES ==========
  static const String _streamUrl = 'https://radio06.cehis.net:9036/stream';
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 8;
  static const bool _autoPlay = true;

  // ========== WAKE LOCK ==========
  static const _wakeLockChannel = MethodChannel(
    'com.miltonbass.ambeinte_stereo_884/wakelock',
  );

  // ========== ESTADO ==========
  bool _isInitialized = false;
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
  // ✅ AGREGADO: Stream para la metadada de la canción actual (Now Playing).
  final BehaviorSubject<Map<String, String>> _metadataController =
      BehaviorSubject<Map<String, String>>.seeded({
        'artist': 'Desconocido',
        'title': 'Cargando...',
      });

  // ========== CONTROL DE RECONEXIÓN ==========
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  // Subscription para los streams del player
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _metadataSubscription;

  // ========== GETTERS PÚBLICOS ==========
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  // ✅ AGREGADO: Getter para la metadada.
  Stream<Map<String, String>> get metadataStream => _metadataController.stream;

  bool get isPlaying => _playingController.value;
  bool get isLoading => _loadingController.value;
  double get volume => _volumeController.value;

  // ========== INICIALIZACIÓN ==========
  Future<void> _initAsync() async {
    if (_isInitialized || _isInitializing) {
      _log('[AudioPlayerManager] Ya está inicializado, ignorando');
      return;
    }

    _isInitializing = true;
    _log('[AudioPlayerManager] Iniciando inicialización...');

    try {
      // Activar WakeLock mediante MainActivity
      try {
        await _wakeLockChannel.invokeMethod('acquireWakeLock');
        _log('[AudioPlayerManager] ✅ WakeLock activado');
      } catch (e) {
        _log('[AudioPlayerManager] ⚠️ Error activando WakeLock: $e');
      }

      // ✅ Configurar estación (radio_player usa métodos estáticos)
      await RadioPlayer.setStation(
        title: 'Ambiente Stereo 88.4 FM',
        url: _streamUrl,
        logoAssetPath: 'assets/images/icon.png', // Logo local
        // O usa una URL remota:
        // logoNetworkUrl: 'https://ambientestereo884.com/logo.png',
      );
      _log('[AudioPlayerManager] ✅ Estación configurada con notificaciones');

      // Configurar listeners de estado
      _setupPlayerListeners();

      _isInitialized = true;
      _isInitializing = false;

      _playingController.add(false);
      _loadingController.add(false);

      _log(
        '[AudioPlayerManager] ✅ Inicialización completa con notificaciones automáticas',
      );

      // Auto-iniciar reproducción
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
      _errorController.add('Error al inicializar: $e');
      _loadingController.add(false);
    }
  }

  void _setupPlayerListeners() {
    // Listener de estado de reproducción
    _playbackStateSubscription = RadioPlayer.playbackStateStream.listen((
      state,
    ) {
      _log('[AudioPlayerManager] 📊 Estado: $state');

      switch (state) {
        case PlaybackState.playing:
          _playingController.add(true);
          _loadingController.add(false);
          _reconnectAttempts = 0;
          _isReconnecting = false;
          break;
        case PlaybackState.paused:
          _playingController.add(false);
          _loadingController.add(false);
          break;
        case PlaybackState.buffering:
          _loadingController.add(true);
          break;
        case PlaybackState.unknown:
          // Estado desconocido - posible error
          _log('[AudioPlayerManager] ⚠️ Estado desconocido');
          if (_playingController.value) {
            // Solo intentar reconectar si estábamos reproduciendo
            _handleReconnection();
          }
          break;
      }
    });

    // Listener de metadata (opcional - para mostrar "Ahora Suena")
    _metadataSubscription = RadioPlayer.metadataStream.listen((metadata) {
      if (metadata.artist != null || metadata.title != null) {
        _log(
          '[AudioPlayerManager] 🎵 Metadata: ${metadata.artist} - ${metadata.title}',
        );
        // ✅ Emitir la nueva metadata
        _metadataController.add({
          'artist': metadata.artist ?? 'Artista Desconocido',
          'title': metadata.title ?? 'Canción Desconocida',
        });
      }
    });
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

      if (!_isInitialized) {
        _errorController.add('Reproductor no disponible');
        _loadingController.add(false);
        return;
      }

      _loadingController.add(true);
      _errorController.add('');

      _log('[AudioPlayerManager] ▶️ Iniciando reproducción...');
      await RadioPlayer.play(); // ✅ Método estático

      _reconnectAttempts = 0;
      _isReconnecting = false;
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al reproducir: $e');
      _loadingController.add(false);
      _errorController.add('Error al conectar');
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _ensureInitialized();

      _log('[AudioPlayerManager] ⏸️ Pausando reproducción...');
      await RadioPlayer.pause(); // ✅ Método estático
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

      final clampedVolume = volume.clamp(0.0, 1.0);
      // Nota: radio_player no tiene control de volumen integrado
      // Usa volume_controller que ya tienes en pubspec.yaml
      _volumeController.add(clampedVolume);
      _log('[AudioPlayerManager] 🔊 Volumen: $clampedVolume');
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
        await RadioPlayer.pause();
        await Future.delayed(const Duration(milliseconds: 500));
        await RadioPlayer.play();
        _isReconnecting = false;
        _errorController.add('Reconectado exitosamente');
        _log('[AudioPlayerManager] ✅ Reconexión exitosa');
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
    await _playbackStateSubscription?.cancel();
    await _metadataSubscription?.cancel();

    await _playingController.close();
    await _loadingController.close();
    await _errorController.close();
    await _volumeController.close();
    await _metadataController.close(); // ✅ Cerrar nuevo stream

    // Liberar WakeLock
    try {
      await _wakeLockChannel.invokeMethod('releaseWakeLock');
      _log('[AudioPlayerManager] ✅ WakeLock liberado');
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error liberando WakeLock: $e');
    }

    // Reset del player
    try {
      await RadioPlayer.reset();
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error al resetear player: $e');
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
