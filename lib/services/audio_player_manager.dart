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

  // ========== ANALYTICS EN TIEMPO REAL ==========
  Timer? _analyticsHeartbeatTimer;
  static const Duration _analyticsInterval = Duration(seconds: 30);
  DateTime? _lastAnalyticsEvent;
  int _continuousPlaybackMinutes = 0;

  factory AudioPlayerManager() {
    _instance ??= AudioPlayerManager._internal();
    return _instance!;
  }

  // ========== FIREBASE STREAMING CONFIG ==========
  // Firebase path: app_config/streaming
  // Reglas Firestore: Lectura pública, escritura autenticada
  // Fallback URL si Firebase no disponible
  static const String _firebaseStreamConfigPath = 'app_config/streaming';
  static String _streamUrl = 'https://radio06.cehis.net:9036/stream'; // Default
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isStreamUrlLoaded = false;

  AudioPlayerManager._internal() {
    _log('[AudioPlayerManager] Creando instancia singleton');
    _initAsync();
  }

  // ========== CONSTANTES ==========
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 8;
  static const bool _autoPlay = true;
  static const Duration _playTimeout = Duration(seconds: 15);
  static const Duration _initTimeout = Duration(seconds: 10);

  // ========== BUFFER INTELIGENTE - CONSTANTES ==========
  static const Duration _progressiveBufferingCheck = Duration(seconds: 3);
  static const Duration _minReconnectInterval = Duration(seconds: 15);

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

  // ========== CONTROL PARA ARTÍCULOS ==========
  bool _isPausedForArticle = false;

  // ========== ESTADO DE BUFFER INTELIGENTE ==========
  int _currentBufferHealth = 3; // Salud inicial máxima
  Timer? _progressiveBufferingTimer;
  DateTime? _lastStablePlayback;
  final List<Duration> _recentBufferingDurations = [];
  double _networkStabilityScore = 1.0; // 0.0 a 1.0
  bool _isNetworkDegraded = false;
  DateTime? _lastBufferingStart;
  bool _isInBufferingState = false;
  DateTime? _lastSuccessfulReconnect;

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

  // ========== GETTER PARA CONTROL DE ARTÍCULOS ==========
  bool get isPausedForArticle => _isPausedForArticle;

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

      // Esperar a que Firebase cargue la URL ANTES de configurar el player
      await _loadStreamUrlFromFirebase();

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
            _handlePlayingState();
            break;

          case PlaybackState.paused:
            _handlePausedState();
            break;

          case PlaybackState.buffering:
            _handleBufferingState();
            break;

          case PlaybackState.unknown:
            _handleUnknownState();
            break;
        }
      },
      onError: (error) {
        _log('[AudioPlayerManager] ❌ Error en playbackStateStream: $error');
        _errorController.add('Error de conexión');
        _loadingController.add(false);

        if ((_playingController.value || _wasPlayingBeforeError) &&
            !_isPausedForArticle) {
          _scheduleReconnectionWithDelay();
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

  // ========== MANEJO INTELIGENTE DE ESTADOS ==========

  /// Maneja el estado de reproducción normal
  void _handlePlayingState() {
    _playingController.add(true);
    _loadingController.add(false);
    _reconnectAttempts = 0;
    _isReconnecting = false;
    _wasPlayingBeforeError = true;
    _errorController.add('');
    _isInBufferingState = false;

    // Cancelar todos los timers de buffering
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;

    // Registrar recuperación exitosa del buffer
    _onPlaybackRecovered();
    _onBufferingResolved();

    _startAudioSession();

    _log(
      '[AudioPlayerManager] ✅ Reproducción normal - Buffer inteligente activo',
    );
  }

  /// Maneja el estado de pausa
  void _handlePausedState() {
    // Limpiar estado de buffering
    _isInBufferingState = false;
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;

    if (_wasPlayingBeforeError &&
        !_isReconnecting &&
        !_isAppInBackground &&
        !_isPausedForArticle) {
      _log(
        '[AudioPlayerManager] ⚠️ Pausa inesperada detectada - posible error de red',
      );
      _scheduleReconnectionWithDelay();
    } else {
      _playingController.add(false);
      _loadingController.add(false);
      // No resetear _wasPlayingBeforeError si es pausa temporal para artículo
      if (!_isPausedForArticle) {
        _wasPlayingBeforeError = false;
      }
      // No finalizar sesión TSL si es pausa temporal
      if (!_isPausedForArticle) {
        _endAudioSession();
      }
    }
  }

  /// Maneja el estado de buffering con inteligencia
  void _handleBufferingState() {
    _loadingController.add(true);
    _isInBufferingState = true;

    _log('[AudioPlayerManager] ⏳ Buffering inteligente activado');

    // Solo manejar buffering si estaba reproduciendo activamente
    if (_wasPlayingBeforeError && !_isAppInBackground && !_isPausedForArticle) {
      _handleIntelligentBuffering();
    }
  }

  /// Maneja estado desconocido del reproductor
  void _handleUnknownState() {
    _log('[AudioPlayerManager] ⚠️ Estado desconocido');

    // Ser más conservador con el estado unknown - esperar antes de reconectar
    if (_playingController.value && !_isReconnecting && !_isPausedForArticle) {
      Future.delayed(const Duration(seconds: 3), () {
        if (_playingController.value && !_isReconnecting) {
          _scheduleReconnectionWithDelay();
        }
      });
    }
  }

  // ========== LÓGICA DE BUFFER INTELIGENTE ==========

  /// Maneja el buffering de forma inteligente evaluando la salud del buffer
  void _handleIntelligentBuffering() {
    _log(
      '[AudioPlayerManager] ⏳ Buffering detectado - Evaluando salud: $_currentBufferHealth/3',
    );

    // Registrar inicio de buffering para tracking
    _lastBufferingStart ??= DateTime.now();

    // Evaluar salud actual de la red
    _evaluateBufferHealth();

    // ESTRATEGIA 1: Buffer health degradation progresiva
    if (_currentBufferHealth > 0) {
      _currentBufferHealth--;
      _log(
        '[AudioPlayerManager] 🟡 Buffer Health reducido: $_currentBufferHealth/3',
      );

      // Intentar recuperación natural con timeout adaptativo
      final adaptiveTimeout = _calculateAdaptiveBufferingTimeout();
      _startProgressiveBufferingCheck(adaptiveTimeout);
    } else {
      // ESTRATEGIA 2: Salud crítica - reconexión necesaria
      _log(
        '[AudioPlayerManager] 🔴 Buffer Health crítico - Reconexión necesaria',
      );
      _handleReconnection();
    }
  }

  /// Evalúa la salud del buffer basado en historial reciente
  void _evaluateBufferHealth() {
    // Limpiar eventos de buffering antiguos (más de 5 minutos)
    _recentBufferingDurations.removeWhere(
      (duration) => duration > const Duration(minutes: 5),
    );

    // Calcular score de estabilidad de red (0.0 a 1.0)
    if (_recentBufferingDurations.isEmpty) {
      _networkStabilityScore = 1.0;
    } else {
      final totalBufferingTime = _recentBufferingDurations.fold(
        Duration.zero,
        (prev, element) => prev + element,
      );
      final totalWindow = const Duration(minutes: 5);
      final bufferingRatio =
          totalBufferingTime.inSeconds / totalWindow.inSeconds;
      _networkStabilityScore = (1.0 - bufferingRatio).clamp(0.1, 1.0);
    }

    _isNetworkDegraded = _networkStabilityScore < 0.6;
    _log(
      '[AudioPlayerManager] 📊 Health Score: ${(_networkStabilityScore * 100).toStringAsFixed(1)}%',
    );
  }

  /// Calcula timeout adaptativo basado en historial de red
  Duration _calculateAdaptiveBufferingTimeout() {
    if (_networkStabilityScore > 0.8) {
      return const Duration(
        seconds: 15,
      ); // Red buena - dar más tiempo para recuperación
    } else if (_networkStabilityScore > 0.5) {
      return const Duration(seconds: 10); // Red regular - timeout moderado
    } else {
      return const Duration(seconds: 8); // Red mala - ser más agresivo
    }
  }

  /// Inicia el monitoreo progresivo del buffering
  void _startProgressiveBufferingCheck(Duration timeout) {
    _progressiveBufferingTimer?.cancel();

    int checkCount = 0;
    const maxChecks = 3;

    _progressiveBufferingTimer = Timer.periodic(_progressiveBufferingCheck, (
      timer,
    ) {
      checkCount++;

      // Verificar si sigue en estado de buffering
      if (_loadingController.value && _wasPlayingBeforeError) {
        if (checkCount >= maxChecks) {
          _log(
            '[AudioPlayerManager] ⚠️ Buffering persistente después de $maxChecks checks',
          );
          timer.cancel();
          _handleReconnection();
          return;
        }

        // Mostrar mensaje progresivo al usuario
        _showIntelligentBufferingMessage(checkCount, maxChecks);
      } else {
        // Buffering se resolvió naturalmente
        _onBufferingResolved();
        timer.cancel();
      }
    });

    // Timeout general como fallback
    Timer(timeout, () {
      if (_progressiveBufferingTimer?.isActive == true) {
        _progressiveBufferingTimer?.cancel();
        if (_loadingController.value) {
          _log(
            '[AudioPlayerManager] ⏱️ Timeout de buffering adaptativo alcanzado',
          );
          _handleReconnection();
        }
      }
    });
  }

  /// Muestra mensajes inteligentes al usuario según el progreso
  void _showIntelligentBufferingMessage(int currentCheck, int maxChecks) {
    final messages = [
      'Optimizando conexión...',
      'Ajustando calidad de audio...',
      'Buscando mejor señal...',
    ];

    String message;
    if (_isNetworkDegraded) {
      message = 'Red lenta - ajustando...';
    } else if (currentCheck < messages.length) {
      message = messages[currentCheck - 1];
    } else {
      message = 'Reconectando...';
    }

    _errorController.add('$message ($currentCheck/$maxChecks)');
  }

  /// Se ejecuta cuando el buffering se resuelve naturalmente
  void _onBufferingResolved() {
    if (_lastBufferingStart != null) {
      final bufferingDuration = DateTime.now().difference(_lastBufferingStart!);
      _recentBufferingDurations.add(bufferingDuration);
      _lastBufferingStart = null;

      // Restaurar salud gradualmente (pero no inmediatamente a máximo)
      _currentBufferHealth = (_currentBufferHealth + 1).clamp(0, 3);

      _log(
        '[AudioPlayerManager] ✅ Buffering resuelto en ${bufferingDuration.inSeconds}s',
      );
      _log(
        '[AudioPlayerManager] 🟢 Buffer Health restaurado: $_currentBufferHealth/3',
      );

      _errorController.add('');
    }
  }

  /// Se ejecuta cuando la reproducción se recupera exitosamente
  void _onPlaybackRecovered() {
    _currentBufferHealth = 3; // Salud máxima
    _lastStablePlayback = DateTime.now();
    _progressiveBufferingTimer?.cancel();
    _lastBufferingStart = null;

    _log(
      '[AudioPlayerManager] 🎉 Playback recuperado - Salud del buffer restaurada',
    );
  }

  // ========== RECONEXIÓN INTELIGENTE ==========

  /// Programa una reconexión con delay para evitar ciclos agresivos
  void _scheduleReconnectionWithDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if ((_playingController.value || _wasPlayingBeforeError) &&
          !_isReconnecting &&
          !_isPausedForArticle) {
        _handleReconnection();
      }
    });
  }

  /// Maneja la lógica de reconexión con inteligencia
  void _handleReconnection() {
    // No reconectar si está pausado para artículo
    if (_isPausedForArticle) {
      _log(
        '[AudioPlayerManager] ℹ️ Ignorando reconexión - pausado para artículo',
      );
      return;
    }

    // Verificar intervalo mínimo entre reconexiones
    if (_lastSuccessfulReconnect != null) {
      final timeSinceLastReconnect = DateTime.now().difference(
        _lastSuccessfulReconnect!,
      );
      if (timeSinceLastReconnect < _minReconnectInterval) {
        _log('[AudioPlayerManager] ⏳ Reconexión muy reciente - ignorando');
        return;
      }
    }

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

    // Mensaje inteligente basado en salud de red
    String userMessage;
    if (_isNetworkDegraded) {
      userMessage = 'Mejorando conexión de red...';
    } else if (_currentBufferHealth <= 0) {
      userMessage = 'Reiniciando stream...';
    } else {
      userMessage = 'Reconectando...';
    }

    _errorController.add(
      '$userMessage ($_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _log(
      '[AudioPlayerManager] 🔄 Intento de reconexión $_reconnectAttempts/$_maxReconnectAttempts',
    );

    _logAnalyticsEvent(
      name: 'connection_retry',
      parameters: {
        'attempt': _reconnectAttempts,
        'max_attempts': _maxReconnectAttempts,
        'buffer_health': _currentBufferHealth,
        'network_score': _networkStabilityScore,
      },
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      try {
        _log('[AudioPlayerManager] 🔄 Ejecutando reconexión inteligente...');

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
        _lastSuccessfulReconnect = DateTime.now();
        _log('[AudioPlayerManager] ✅ Reconexión inteligente exitosa');

        _logAnalyticsEvent(
          name: 'reconnection_success',
          parameters: {
            'attempt': _reconnectAttempts,
            'buffer_health_restored': true,
          },
        );
      } catch (e) {
        _log('[AudioPlayerManager] ❌ Error en reconexión inteligente: $e');
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
          'buffer_intelligent': true, // Indicar que usa buffer inteligente
        },
      );

      // Iniciar heartbeat de analytics
      _startAnalyticsHeartbeat();

      _log('[AudioPlayerManager] 📊 TSL Iniciada con buffer inteligente');
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
            'buffer_health': _currentBufferHealth, // Salud del buffer
            'network_stability': _networkStabilityScore, // Estabilidad de red
          },
        );

        _log(
          '[AudioPlayerManager] 📊 Heartbeat enviado - ${_continuousPlaybackMinutes}min continuos - Salud: $_currentBufferHealth/3',
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
          'final_buffer_health': _currentBufferHealth,
          'average_network_stability': _networkStabilityScore,
        },
      );

      _log('[AudioPlayerManager] 📊 TSL Finalizada: ${durationSeconds}s');
      _log(
        '[AudioPlayerManager] 📊 Minutos continuos: $_continuousPlaybackMinutes',
      );
      _log('[AudioPlayerManager] 📊 Total reconexiones: $_totalReconnections');
      _log(
        '[AudioPlayerManager] 📊 Salud final del buffer: $_currentBufferHealth/3',
      );

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
          'buffer_health_at_pause': _currentBufferHealth,
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
        '[AudioPlayerManager] 📊 TSL continúa: ${duration.inSeconds}s acumulados - Salud: $_currentBufferHealth/3',
      );
    }
  }

  // ========== MÉTODOS PARA CONTROL DE ARTÍCULOS ==========

  /// Pausar la radio temporalmente para reproducir un artículo
  Future<void> pauseForArticle() async {
    if (isPlaying && !_isPausedForArticle) {
      _isPausedForArticle = true;
      _wasPlayingBeforeError = false; // Importante: evitar reconexión
      await pause();
      _log('[AudioPlayerManager] ⏸️ Pausado temporalmente para artículo');

      await _logAnalyticsEvent(
        name: 'radio_paused_for_article',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'buffer_health': _currentBufferHealth,
        },
      );
    }
  }

  /// Reanudar la radio después de terminar un artículo
  Future<void> resumeAfterArticle() async {
    if (_isPausedForArticle) {
      _isPausedForArticle = false;
      _log('[AudioPlayerManager] ▶️ Reanudando después de artículo');

      // Esperar un poco antes de reanudar
      await Future.delayed(const Duration(milliseconds: 500));
      await play();

      await _logAnalyticsEvent(
        name: 'radio_resumed_after_article',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'buffer_health': _currentBufferHealth,
        },
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
        parameters: {
          'action': isPlaying ? 'pause' : 'play',
          'buffer_health': _currentBufferHealth,
        },
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

      _log(
        '[AudioPlayerManager] ▶️ Iniciando reproducción con buffer inteligente...',
      );

      await RadioPlayer.play().timeout(
        _playTimeout,
        onTimeout: () {
          throw TimeoutException('La conexión tardó demasiado');
        },
      );

      _reconnectAttempts = 0;
      _isReconnecting = false;
      _lastSuccessfulReconnect = DateTime.now();
      _recentBufferingDurations.clear(); // Limpiar historial en nueva conexión

      await _logAnalyticsEvent(
        name: 'play_button_pressed',
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'timestamp': DateTime.now().toIso8601String(),
          'buffer_health': _currentBufferHealth,
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
        parameters: {
          'error': e.toString().substring(0, 100),
          'buffer_health': _currentBufferHealth,
        },
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
        parameters: {
          'station': 'Ambiente Stereo 88.4',
          'buffer_health': _currentBufferHealth,
        },
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

    // Detener todos los timers
    _analyticsHeartbeatTimer?.cancel();
    _analyticsHeartbeatTimer = null;
    _progressiveBufferingTimer?.cancel();
    _progressiveBufferingTimer = null;

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

  // ========== DEBUG INFO MEJORADO ==========
  Map<String, dynamic> getDebugInfo() {
    return {
      'isInitialized': _isInitialized,
      'isPlaying': isPlaying,
      'isLoading': isLoading,
      'isPausedForArticle': _isPausedForArticle,
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
      // INFO DE BUFFER INTELIGENTE
      'bufferIntelligence': {
        'buffer_health': '$_currentBufferHealth/3',
        'network_stability_score':
            '${(_networkStabilityScore * 100).toStringAsFixed(1)}%',
        'is_network_degraded': _isNetworkDegraded,
        'recent_buffering_events': _recentBufferingDurations.length,
        'last_stable_playback': _lastStablePlayback?.toIso8601String(),
        'adaptive_timeout_seconds':
            _calculateAdaptiveBufferingTimeout().inSeconds,
        'last_buffering_start': _lastBufferingStart?.toIso8601String(),
        'is_in_buffering_state': _isInBufferingState,
      },
    };
  }
}
