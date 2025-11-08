import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:radio_player/radio_player.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Gestor centralizado del reproductor de audio usando radio_player
/// Implementa el patrón Singleton para mantener una única instancia
/// Maneja el streaming de radio, control de volumen y estado de reproducción
/// Incluye notificaciones automáticas y manejo robusto de errores
class AudioPlayerManager {
  // ========== SINGLETON PATTERN ==========
  static AudioPlayerManager? _instance;

  // ========== NUEVO: ANALYTICS EN TIEMPO REAL ==========
  Timer? _analyticsHeartbeatTimer;
  static const Duration _analyticsInterval = Duration(seconds: 30);
  DateTime? _lastAnalyticsEvent;
  int _continuousPlaybackMinutes = 0;

  factory AudioPlayerManager() {
    _instance ??= AudioPlayerManager._internal();
    return _instance!;
  }

  // ========== NUEVO: FIREBASE STREAMING CONFIG ==========
  static const String _firebaseStreamConfigPath = 'app_config/streaming';
  static String _streamUrl = 'https://radio06.cehis.net:9036/stream'; // Default
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isStreamUrlLoaded = false;

  AudioPlayerManager._internal() {
    _log('[AudioPlayerManager] Creando instancia singleton');
    _loadStreamUrlFromFirebase();
    _initAsync();
  }

  // ========== CONSTANTES ==========
  //static const String _streamUrl = 'https://radio06.cehis.net:9036/stream';
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 8;
  static const bool _autoPlay = true;
  static const Duration _playTimeout = Duration(seconds: 15);
  static const Duration _initTimeout = Duration(seconds: 10);

  // ========== ANALYTICS Y ESTADO DE TSL ==========
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  DateTime? _startTime;
  int _totalReconnections = 0;

  // ========== WAKE LOCK ==========
  static const _wakeLockChannel = MethodChannel(
    'com.miltonbass.ambeinte_stereo_884/wakelock',
  );
  bool _wakeLockAvailable = false;
  bool _wakeLockAcquired = false;

  // ========== ESTADO ==========
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();
  bool _wasPlayingBeforeError = false;
  bool _isAppInBackground = false; // Track estado de app

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
  final BehaviorSubject<Map<String, String>> _metadataController =
      BehaviorSubject<Map<String, String>>.seeded({});

  // ========== CONTROL DE RECONEXIÓN ==========
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  DateTime? _lastReconnectAttempt;

  // Subscription para los streams del player
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _metadataSubscription;

  // ========== GETTERS PÚBLICOS ==========
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<Map<String, String>> get metadataStream => _metadataController.stream;

  bool get isPlaying => _playingController.value;
  bool get isLoading => _loadingController.value;
  double get volume => _volumeController.value;
  bool get isInitialized => _isInitialized;

  /// Carga la URL del streaming desde Firebase
  Future<void> _loadStreamUrlFromFirebase() async {
    try {
      _log('[AudioPlayerManager] 📡 Cargando URL desde Firebase...');

      final doc = await _firestore
          .doc(_firebaseStreamConfigPath)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final config = doc.data()!;
        final newStreamUrl = config['stream_url'] as String?;

        if (newStreamUrl != null && newStreamUrl.isNotEmpty) {
          _streamUrl = newStreamUrl;
          _isStreamUrlLoaded = true;
          _log(
            '[AudioPlayerManager] ✅ URL cargada desde Firebase: $_streamUrl',
          );
        }
      }
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Usando URL default: $e');
    }
  }

  // ========== INICIALIZACIÓN ==========
  Future<void> _initAsync() async {
    if (_isInitialized || _isInitializing) {
      _log('[AudioPlayerManager] Ya está inicializado o en proceso');
      return;
    }

    _isInitializing = true;
    _loadingController.add(true);
    _log('[AudioPlayerManager] Iniciando inicialización...');

    try {
      await _initializeWakeLock();

      await RadioPlayer.setStation(
        title: 'Ambiente Stereo 88.4 FM',
        url: _streamUrl,
        logoAssetPath: 'assets/images/icon.png',
      );
      _log('[AudioPlayerManager] ✅ Estación configurada con URL: $_streamUrl');

      _setupPlayerListeners();

      _isInitialized = true;
      _isInitializing = false;

      _playingController.add(false);
      _loadingController.add(false);

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      _log('[AudioPlayerManager] ✅ Inicialización completa');

      await _logAnalyticsEvent(
        name: 'player_initialized',
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'auto_play': _autoPlay ? 'true' : 'false',
          'wakelock_available': _wakeLockAvailable ? 'true' : 'false',
          'stream_url_source': _isStreamUrlLoaded ? 'firebase' : 'default',
        },
      );

      if (_autoPlay) {
        _log('[AudioPlayerManager] 🎵 Auto-iniciando reproducción...');
        Future.delayed(const Duration(milliseconds: 500), () {
          play();
        });
      }
    } catch (e, stackTrace) {
      _isInitializing = false;
      _isInitialized = false;

      _log('[AudioPlayerManager] ❌ Error en inicialización: $e');
      _log('[AudioPlayerManager] Stack trace: $stackTrace');

      _errorController.add('Error al inicializar: $e');
      _loadingController.add(false);

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stackTrace);
      }

      await _logAnalyticsEvent(
        name: 'player_init_error',
        parameters: {'error': e.toString().substring(0, 100)},
      );
    }
  }

  Future<void> _initializeWakeLock() async {
    try {
      await _wakeLockChannel
          .invokeMethod<bool>('acquireWakeLock')
          .timeout(const Duration(seconds: 2));

      _wakeLockAvailable = true;
      _wakeLockAcquired = true;
      _log('[AudioPlayerManager] ✅ WakeLock activado');
    } on MissingPluginException {
      _wakeLockAvailable = false;
      _log(
        '[AudioPlayerManager] ⚠️ WakeLock no disponible - implementación nativa faltante',
      );
      _log('[AudioPlayerManager] ℹ️ La app funcionará sin WakeLock');
    } on TimeoutException {
      _wakeLockAvailable = false;
      _log('[AudioPlayerManager] ⚠️ WakeLock timeout - no disponible');
    } catch (e) {
      _wakeLockAvailable = false;
      _log('[AudioPlayerManager] ⚠️ Error verificando WakeLock: $e');
    }
  }

  void _setupPlayerListeners() {
    _playbackStateSubscription = RadioPlayer.playbackStateStream.listen(
      (state) {
        _log('[AudioPlayerManager] 📊 Estado: $state');

        switch (state) {
          case PlaybackState.playing:
            _playingController.add(true);
            _loadingController.add(false);
            _reconnectAttempts = 0;
            _isReconnecting = false;
            _wasPlayingBeforeError = true;
            _errorController.add('');
            _startAudioSession();
            break;

          case PlaybackState.paused:
            // Detectar si la pausa fue por error (no por background)
            if (_wasPlayingBeforeError &&
                !_isReconnecting &&
                !_isAppInBackground) {
              _log(
                '[AudioPlayerManager] ⚠️ Pausa inesperada detectada - posible error de red',
              );
              _handleReconnection();
            } else {
              _playingController.add(false);
              _loadingController.add(false);
              _wasPlayingBeforeError = false;
              _endAudioSession();
            }
            break;

          case PlaybackState.buffering:
            _loadingController.add(true);
            _log('[AudioPlayerManager] ⏳ Buffering...');

            // ✅ NUEVO: Si estábamos reproduciendo y NO es por background, podría ser error
            if (_wasPlayingBeforeError && !_isAppInBackground) {
              // Dar tiempo para que se resuelva el buffering
              Future.delayed(const Duration(seconds: 3), () {
                // Si después de 3 segundos sigue buffering, reconectar
                if (_loadingController.value &&
                    _wasPlayingBeforeError &&
                    !_isReconnecting) {
                  _log(
                    '[AudioPlayerManager] ⚠️ Buffering prolongado - reconectando',
                  );
                  _handleReconnection();
                }
              });
            }
            break;

          case PlaybackState.unknown:
            _log('[AudioPlayerManager] ⚠️ Estado desconocido');
            if (_playingController.value && !_isReconnecting) {
              _handleReconnection();
            }
            break;
        }
      },
      onError: (error) {
        _log('[AudioPlayerManager] ❌ Error en playbackStateStream: $error');
        _errorController.add('Error de conexión');
        _loadingController.add(false);

        if (_playingController.value || _wasPlayingBeforeError) {
          _handleReconnection();
        }
      },
      cancelOnError: false,
    );

    _metadataSubscription = RadioPlayer.metadataStream.listen(
      (metadata) {
        if (metadata.artist != null || metadata.title != null) {
          final data = {
            'artist': metadata.artist ?? 'Desconocido',
            'title': metadata.title ?? 'Sin título',
          };
          _log(
            '[AudioPlayerManager] 🎵 Metadata: ${data['artist']} - ${data['title']}',
          );
          _metadataController.add(data);

          _logAnalyticsEvent(
            name: 'song_changed',
            parameters: {'artist': data['artist']!, 'title': data['title']!},
          );
        }
      },
      onError: (error) {
        _log('[AudioPlayerManager] ⚠️ Error en metadataStream: $error');
      },
      cancelOnError: false,
    );
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (_isInitializing) {
      _log('[AudioPlayerManager] ⏳ Esperando inicialización en curso...');
      try {
        await _initCompleter.future.timeout(_initTimeout);
        _log('[AudioPlayerManager] ✅ Inicialización completada');
      } on TimeoutException {
        _log('[AudioPlayerManager] ⏱️ Timeout esperando inicialización');
        throw Exception('Timeout en inicialización');
      } catch (e) {
        _log('[AudioPlayerManager] ❌ Error esperando inicialización: $e');
        rethrow;
      }
      return;
    }

    if (!_isInitialized) {
      _log('[AudioPlayerManager] 🔄 Iniciando inicialización...');
      await _initAsync();
    }
  }

  // ========== TSL LOGIC ==========

  void _startAudioSession() {
    if (_startTime == null) {
      _startTime = DateTime.now();
      _continuousPlaybackMinutes = 0;

      _logAnalyticsEvent(
        name: 'audio_session_start',
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'timestamp': DateTime.now().toIso8601String(),
          'stream_url_source': _isStreamUrlLoaded ? 'firebase' : 'default',
        },
      );

      // Iniciar heartbeat de analytics
      _startAnalyticsHeartbeat();

      _log('[AudioPlayerManager] 📊 TSL Iniciada');
    }
  }

  /// Envía eventos periódicos mientras el streaming está activo
  void _startAnalyticsHeartbeat() {
    _analyticsHeartbeatTimer?.cancel();
    _analyticsHeartbeatTimer = Timer.periodic(_analyticsInterval, (
      timer,
    ) async {
      if (_playingController.value && _startTime != null) {
        _continuousPlaybackMinutes++;
        _lastAnalyticsEvent = DateTime.now();

        final sessionDuration = DateTime.now().difference(_startTime!);

        await _logAnalyticsEvent(
          name: 'streaming_heartbeat',
          parameters: {
            'station': 'Ambiente Stereo 88.4',
            'continuous_minutes': _continuousPlaybackMinutes,
            'total_session_minutes': sessionDuration.inMinutes,
            'is_reconnecting': _isReconnecting ? 'true' : 'false',
            'reconnect_attempts': _reconnectAttempts,
            'stream_url_source': _isStreamUrlLoaded ? 'firebase' : 'default',
            'last_heartbeat': _lastAnalyticsEvent?.toIso8601String(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        _log(
          '[AudioPlayerManager] 📊 Heartbeat enviado - ${_continuousPlaybackMinutes}min continuos',
        );
      } else {
        // Si no está reproduciendo, detener el heartbeat
        timer.cancel();
      }
    });
  }

  void _endAudioSession() {
    if (_startTime != null) {
      final duration = DateTime.now().difference(_startTime!);
      final durationSeconds = duration.inSeconds;

      // Detener heartbeat
      _analyticsHeartbeatTimer?.cancel();
      _analyticsHeartbeatTimer = null;

      _logAnalyticsEvent(
        name: 'audio_session_end',
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'session_duration_sec': durationSeconds,
          'continuous_minutes': _continuousPlaybackMinutes,
          'total_reconnections': _totalReconnections,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      _log('[AudioPlayerManager] 📊 TSL Finalizada: ${durationSeconds}s');
      _log(
        '[AudioPlayerManager] 📊 Minutos continuos: $_continuousPlaybackMinutes',
      );
      _log('[AudioPlayerManager] 📊 Total reconexiones: $_totalReconnections');

      _startTime = null;
      _continuousPlaybackMinutes = 0;
      _totalReconnections = 0;
    }
  }

  // Lifecycle tracking con flag de background
  void onAppPaused() {
    _log('[AudioPlayerManager] 🔵 App pausada/background');
    _isAppInBackground = true;

    // Pausar heartbeat en background
    _analyticsHeartbeatTimer?.cancel();

    // Guardar TSL temporal si está reproduciendo
    if (_startTime != null && isPlaying) {
      final duration = DateTime.now().difference(_startTime!);
      _log(
        '[AudioPlayerManager] 📊 TSL checkpoint (background): ${duration.inSeconds}s',
      );

      // Registrar evento de background (no finalizar sesión)
      _logAnalyticsEvent(
        name: 'audio_session_background',
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'duration_so_far': duration.inSeconds,
          'continuous_minutes': _continuousPlaybackMinutes,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  void onAppResumed() {
    _log('[AudioPlayerManager] 🟢 App resumida/foreground');
    _isAppInBackground = false;

    // La sesión TSL continúa si el audio sigue reproduciendo
    if (isPlaying && _startTime != null) {
      _startAnalyticsHeartbeat();

      final duration = DateTime.now().difference(_startTime!);
      _log(
        '[AudioPlayerManager] 📊 TSL continúa: ${duration.inSeconds}s acumulados',
      );
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

      await _logAnalyticsEvent(
        name: 'toggle_playback',
        parameters: {'action': isPlaying ? 'pause' : 'play'},
      );
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

      _wasPlayingBeforeError = false;
      _loadingController.add(true);
      _errorController.add('');

      _log('[AudioPlayerManager] ▶️ Iniciando reproducción...');

      await RadioPlayer.play().timeout(
        _playTimeout,
        onTimeout: () {
          throw TimeoutException('La conexión tardó demasiado');
        },
      );

      _reconnectAttempts = 0;
      _isReconnecting = false;

      await _logAnalyticsEvent(
        name: 'play_button_pressed',
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on TimeoutException catch (e) {
      _log('[AudioPlayerManager] ⏱️ Timeout al reproducir: $e');
      _loadingController.add(false);
      _errorController.add('Conexión lenta. Reintentando...');
      _handleReconnection();
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al reproducir: $e');
      _loadingController.add(false);
      _errorController.add('Error al conectar');

      await _logAnalyticsEvent(
        name: 'play_error',
        parameters: {'error': e.toString().substring(0, 100)},
      );
    }
  }

  Future<void> pause() async {
    try {
      await _ensureInitialized();

      _log('[AudioPlayerManager] ⏸️ Pausando reproducción...');
      _wasPlayingBeforeError = false;
      await RadioPlayer.pause();
      _loadingController.add(false);

      _reconnectTimer?.cancel();
      _isReconnecting = false;
      _reconnectAttempts = 0;

      await _logAnalyticsEvent(
        name: 'pause_button_pressed',
        parameters: {'station': 'Ambiente Stereo 88.4'},
      );
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
      final oldVolume = _volumeController.value;
      _volumeController.add(clampedVolume);

      final volumePercent = (clampedVolume * 100).toInt();
      _log('[AudioPlayerManager] 🔊 Volumen: $volumePercent%');

      if ((clampedVolume * 10).round() != (oldVolume * 10).round()) {
        await _logAnalyticsEvent(
          name: 'volume_changed',
          parameters: {'volume': volumePercent},
        );
      }
    } catch (e) {
      _log('[AudioPlayerManager] ❌ Error al cambiar volumen: $e');
    }
  }

  // ========== RECONEXIÓN AUTOMÁTICA ==========

  void _handleReconnection() {
    if (_isReconnecting) {
      _log('[AudioPlayerManager] ⚠️ Reconexión ya en progreso...');
      return;
    }

    if (!_wasPlayingBeforeError && !_playingController.value) {
      _log('[AudioPlayerManager] ℹ️ No reconectar - usuario pausó manualmente');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('[AudioPlayerManager] ❌ Máximo de reconexiones alcanzado');
      _errorController.add(
        'No se pudo reconectar. Presiona ▶ para reintentar.',
      );
      _loadingController.add(false);
      _playingController.add(false);
      _wasPlayingBeforeError = false;

      _logAnalyticsEvent(
        name: 'reconnection_failed',
        parameters: {
          'attempts': _reconnectAttempts,
          'max_attempts': _maxReconnectAttempts,
        },
      );

      return;
    }

    if (_lastReconnectAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(
        _lastReconnectAttempt!,
      );
      if (timeSinceLastAttempt.inSeconds < 2) {
        _log('[AudioPlayerManager] ⏳ Esperando antes de reintentar...');
        return;
      }
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    _totalReconnections++;
    _lastReconnectAttempt = DateTime.now();
    _loadingController.add(true);
    _errorController.add(
      'Reconectando... ($_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _log(
      '[AudioPlayerManager] 🔄 Intento de reconexión $_reconnectAttempts/$_maxReconnectAttempts',
    );

    _logAnalyticsEvent(
      name: 'connection_retry',
      parameters: {
        'attempt': _reconnectAttempts,
        'max_attempts': _maxReconnectAttempts,
      },
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      try {
        _log('[AudioPlayerManager] 🔄 Ejecutando reconexión...');

        await RadioPlayer.pause();
        await Future.delayed(const Duration(milliseconds: 500));

        await RadioPlayer.play().timeout(
          _playTimeout,
          onTimeout: () {
            throw TimeoutException('Timeout en reconexión');
          },
        );

        _isReconnecting = false;
        _errorController.add('');
        _log('[AudioPlayerManager] ✅ Reconexión exitosa');

        _logAnalyticsEvent(
          name: 'reconnection_success',
          parameters: {'attempt': _reconnectAttempts},
        );
      } catch (e) {
        _log('[AudioPlayerManager] ❌ Error en reconexión: $e');
        _isReconnecting = false;

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _handleReconnection();
          } else {
            _errorController.add(
              'Conexión perdida. Presiona ▶ para reintentar.',
            );
            _playingController.add(false);
            _loadingController.add(false);
            _wasPlayingBeforeError = false;
          }
        });
      }
    });
  }

  void resetReconnectionAttempts() {
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _errorController.add('');
    _wasPlayingBeforeError = false;
    _log('[AudioPlayerManager] 🔄 Contador de reconexión reseteado');
  }

  // ========== CLEANUP ==========
  Future<void> dispose() async {
    _log('[AudioPlayerManager] 🧹 Liberando recursos...');

    // Detener heartbeat
    _analyticsHeartbeatTimer?.cancel();
    _analyticsHeartbeatTimer = null;

    _endAudioSession();
    _reconnectTimer?.cancel();
    await _playbackStateSubscription?.cancel();
    await _metadataSubscription?.cancel();

    await _playingController.close();
    await _loadingController.close();
    await _errorController.close();
    await _volumeController.close();
    await _metadataController.close();

    if (_wakeLockAvailable && _wakeLockAcquired) {
      try {
        await _wakeLockChannel.invokeMethod<bool>('releaseWakeLock');
        _wakeLockAcquired = false;
        _log('[AudioPlayerManager] ✅ WakeLock liberado');
      } catch (e) {
        _log('[AudioPlayerManager] ⚠️ Error liberando WakeLock: $e');
      }
    }

    try {
      await RadioPlayer.reset();
      _log('[AudioPlayerManager] ✅ Player reseteado');
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error al resetear player: $e');
    }

    _log('[AudioPlayerManager] ✅ Recursos liberados completamente');
  }

  // ========== LOGGING ==========
  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  Future<void> _logAnalyticsEvent({
    required String name,
    required Map<String, dynamic> parameters,
  }) async {
    try {
      final cleanParams = <String, Object>{};

      parameters.forEach((key, value) {
        if (value is String) {
          cleanParams[key] = value;
        } else if (value is num) {
          cleanParams[key] = value;
        } else if (value is bool) {
          cleanParams[key] = value ? 'true' : 'false';
        } else {
          cleanParams[key] = value.toString();
        }
      });

      await _analytics.logEvent(name: name, parameters: cleanParams);
    } catch (e) {
      _log('[AudioPlayerManager] ⚠️ Error en Analytics: $e');
    }
  }

  // ========== DEBUG INFO ==========
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isPlaying': isPlaying,
      'isLoading': isLoading,
      'streamUrl': _streamUrl,
      'streamUrlSource': _isStreamUrlLoaded ? 'firebase' : 'default',
      'reconnectAttempts': _reconnectAttempts,
      'totalReconnections': _totalReconnections,
      'isReconnecting': _isReconnecting,
      'wasPlayingBeforeError': _wasPlayingBeforeError,
      'isAppInBackground': _isAppInBackground,
      'volume': volume,
      'sessionActive': _startTime != null,
      'sessionDuration': _startTime != null
          ? DateTime.now().difference(_startTime!).inSeconds
          : 0,
      'wakeLockAvailable': _wakeLockAvailable,
      'wakeLockAcquired': _wakeLockAcquired,
    };
  }
}
